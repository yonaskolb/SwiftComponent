import Foundation
import SwiftUI
import Combine
import CasePaths
import Dependencies

@dynamicMemberLookup
public class ComponentModelStore<Model: ComponentModel> {

    weak var store: ComponentStore<Model>!

    public var cancellables: Set<AnyCancellable> = []

    init(store: ComponentStore<Model>) {
        self.store = store
    }

    public var route: Model.Route? { store.route }
    public var state: Model.State { store.state }
    public var path: ComponentPath { store.path }
    public var dependencies: ComponentDependencies { store.dependencies }

    public func mutate<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, _ value: Value, animation: Animation? = nil, file: StaticString = #file, line: UInt = #line) {
        store.mutate(keyPath, value: value, animation: animation, source: .capture(file: file, line: line))
    }

    public func output(_ event: Model.Output, file: StaticString = #file, line: UInt = #line) {
        store.output(event, source: .capture(file: file, line: line))
    }

    @MainActor
    public subscript<Value>(dynamicMember keyPath: WritableKeyPath<Model.State, Value>) -> Value {
        get { store.state[keyPath: keyPath] }
        set {
            // TODO: can't capture source location
            // https://forums.swift.org/t/add-default-parameter-support-e-g-file-to-dynamic-member-lookup/58490/2
            store.mutate(keyPath, value: newValue, source: nil)
        }
    }

    public func addTask(_ taskID: Model.Task, cancellable: Bool = false, cancelID: String? = nil, file: StaticString = #file, line: UInt = #line, _ task: @escaping () async -> Void) {
        store.addTask { @MainActor [weak self] in
            await self?.store.task(taskID.taskName, cancellable: cancellable, source: .capture(file: file, line: line), task)
        }
    }

    public func task(_ taskID: Model.Task, cancellable: Bool = false, file: StaticString = #file, line: UInt = #line, _ task: @escaping () async -> Void) async {
        await store.task(taskID.taskName, cancellable: cancellable, source: .capture(file: file, line: line), task)
    }

    public func task<R>(_ taskID: Model.Task, cancellable: Bool = false, file: StaticString = #file, line: UInt = #line, _ task: @escaping () async throws -> R, catch catchError: (Error) -> Void) async {
        await store.task(taskID.taskName, cancellable: cancellable, source: .capture(file: file, line: line), task, catch: catchError)
    }

    public func cancelTask(_ taskID: Model.Task) {
        store.cancelTask(cancelID: taskID.taskName)
    }

    public func dismissRoute(file: StaticString = #file, line: UInt = #line) {
        store.dismissRoute(source: .capture(file: file, line: line))
    }

    public func statePublisher() -> AnyPublisher<Model.State, Never> {
        store.stateChanged
            .eraseToAnyPublisher()
    }

    // removes duplicates from equatable values, so only changes are published
    public func statePublisher<Value: Equatable>(_ keypath: KeyPath<Model.State, Value>) -> AnyPublisher<Value, Never> {
        statePublisher()
            .map { $0[keyPath: keypath] }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    deinit {
//        print("deinit ModelStore \(Model.baseName)")
    }
}

func getResourceTaskName<State, R>(_ keyPath: KeyPath<State, Resource<R>>) -> String {
    "load \(keyPath.propertyName ?? "resource")"
}

extension ComponentModelStore {

    @MainActor
    public func loadResource<ResourceState>(_ keyPath: WritableKeyPath<Model.State, Resource<ResourceState>>, animation: Animation? = nil, overwriteContent: Bool = true, file: StaticString = #file, line: UInt = #line, load: @MainActor @escaping () async throws -> ResourceState) async {
        mutate(keyPath.appending(path: \.isLoading), true, animation: animation)
        let name = getResourceTaskName(keyPath)
        await store.task(name, cancellable: true, source: .capture(file: file, line: line)) {
            let content = try await load()
            self.mutate(keyPath.appending(path: \.content), content, animation: animation)
            if self.store.state[keyPath: keyPath.appending(path: \.error)] != nil {
                self.mutate(keyPath.appending(path: \.error), nil, animation: animation)
            }
            return content
        } catch: { error in
            if overwriteContent, store.state[keyPath: keyPath.appending(path: \.content)] != nil {
                mutate(keyPath.appending(path: \.content), nil, animation: animation)
            }
            mutate(keyPath.appending(path: \.error), error, animation: animation)
        }
        mutate(keyPath.appending(path: \.isLoading), false, animation: animation)
    }
}
