import Foundation
import Dependencies

@dynamicMemberLookup
public class ComponentDependencies {

    var dependencyValues: DependencyValues
    var accessedDependencies: Set<String> = []
    var setDependencies: Set<String> = []
    let lock = NSLock()

    init() {
        dependencyValues = DependencyValues._current
    }

    func withLock<T>(_ closure: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return closure()
    }

    public func setDependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, _ dependency: T) {
        withLock {
            if let name = keyPath.propertyName {
                setDependencies.insert(name)
            }
            dependencyValues[keyPath: keyPath] = dependency
        }
    }

    public subscript<Value>(dynamicMember keyPath: KeyPath<DependencyValues, Value>) -> Value {
        withLock {
            if let name = keyPath.propertyName {
                accessedDependencies.insert(name)
            }
            return dependencyValues[keyPath: keyPath]
        }
    }

    func apply(_ dependencies: ComponentDependencies) {
        withLock {
            self.dependencyValues = self.dependencyValues.merging(dependencies.dependencyValues)
        }
    }

    func setValues(_ values: DependencyValues) {
        withLock {
            self.dependencyValues = values
        }
    }

    func reset() {
        withLock {
            accessedDependencies = []
            setDependencies = []
            dependencyValues = DependencyValues._current
        }
    }
}

public protocol DependencyContainer {
    var dependencies: ComponentDependencies { get }
}

extension DependencyContainer {

    public func dependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, _ value: T) -> Self {
        self.dependencies.setDependency(keyPath, value)
        return self
    }

    func apply(_ dependencies: ComponentDependencies) -> Self {
        self.dependencies.apply(dependencies)
        return self
    }
}

extension ViewModel: DependencyContainer { }
extension Test: DependencyContainer { }
extension ComponentSnapshot: DependencyContainer { }

extension ComponentRoute {

    @discardableResult
    public func dependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, _ value: T) -> Self {
        if let store {
            store.dependencies.setDependency(keyPath, value)
        } else {
            self.dependencies.setDependency(keyPath, value)
        }
        return self
    }
}

extension TestStep {
    public func dependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, _ dependency: T, file: StaticString = #filePath, line: UInt = #line) -> Self {
        beforeRun { context in
            context.model.dependencies.setDependency(keyPath, dependency)
        }
    }
}

extension Test {
    public func dependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, _ dependency: T, file: StaticString = #filePath, line: UInt = #line) -> Self {
        let test = self
        test.dependencies.setDependency(keyPath, dependency)
        return test
    }
}
