//
//  File.swift
//  
//
//  Created by Yonas Kolb on 15/4/2023.
//

import Foundation
import Dependencies

@dynamicMemberLookup
public class ComponentDependencies {

    var dependencyValues: DependencyValues
    var accessedDependencies: Set<String> = []
    var setDependencies: Set<String> = []

    init() {
        dependencyValues = DependencyValues._current
    }

    public func setDependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, _ dependency: T) {
        if let name = keyPath.propertyName {
            setDependencies.insert(name)
        }
        dependencyValues[keyPath: keyPath] = dependency
    }

    public subscript<Value>(dynamicMember keyPath: KeyPath<DependencyValues, Value>) -> Value {
        if let name = keyPath.propertyName {
            accessedDependencies.insert(name)
        }
        let dependencies = self.dependencyValues.merging(DependencyValues._current)
        return DependencyValues.$_current.withValue(dependencies) {
            DependencyValues._current[keyPath: keyPath]
        }
    }

    func apply(_ dependencies: ComponentDependencies) {
        self.dependencyValues = self.dependencyValues.merging(dependencies.dependencyValues)
    }

    func reset() {
        accessedDependencies = []
        setDependencies = []
        dependencyValues = DependencyValues._current
    }
}

extension ViewModel {

    public func dependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, _ value: T) -> Self {
        self.store.dependencies.setDependency(keyPath, value)
        return self
    }

    func apply(_ dependencies: ComponentDependencies) -> Self {
        self.store.dependencies.apply(dependencies)
        return self
    }
}

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
