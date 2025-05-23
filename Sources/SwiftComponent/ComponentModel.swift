import Foundation
import SwiftUI
import Combine

@MainActor
public protocol ComponentModel<State, Action>: DependencyContainer {

    associatedtype State = Void
    associatedtype Action = Never
    associatedtype Input = Never
    associatedtype Output = Never
    associatedtype Route = Never
    associatedtype Task: ModelTask = Never
    associatedtype Environment: ComponentEnvironment = EmptyEnvironment
    associatedtype Connections = Void
    @MainActor func appear() async
    @MainActor func firstAppear() async
    @MainActor func disappear() async
    @MainActor func binding(keyPath: PartialKeyPath<State>) async
    @MainActor func handle(action: Action) async
    @MainActor func handle(input: Input) async
    var _$connections: Connections { get }
    func handle(event: Event)
    @discardableResult nonisolated func connect(route: Route) -> RouteConnection
    nonisolated init(context: Context)
    var _$context: Context { get }

    typealias Context = ModelContext<Self>
    typealias Connection<Model: ComponentModel> = ModelConnection<Self, Model>
    typealias Scope<Model: ComponentModel> = ComponentConnection<Self, Model>
}

public protocol ModelTask {
    var taskName: String { get }
}

extension Never: ModelTask {
    public var taskName: String { "" }
}

extension RawRepresentable where RawValue == String {
    public var taskName: String { rawValue }
}

extension ComponentModel {
    
    public var state: Context { _$context }
    
    var connections: Connections { _$connections }
    
    nonisolated static var name: String {
        String(describing: Self.self)
    }

    nonisolated public static var baseName: String {
        var name = self.name
        let suffixes: [String] = [
            "Component",
            "Model",
            "Feature",
        ]
        for suffix in suffixes {
            if name.hasSuffix(suffix) && name.count > suffix.count {
                name = String(name.dropLast(suffix.count))
            }
        }
        return name
    }
}

public extension ComponentModel where Connections == Void {
    var connections: Connections { () }
}

public extension ComponentModel where Action == Void {
    func handle(action: Void) async {}
}

public extension ComponentModel where Input == Void {
    func handle(input: Void) async {}
}

public extension ComponentModel where Route == Never {
    nonisolated func connect(route: Route) -> RouteConnection { RouteConnection() }
}

// default handlers
public extension ComponentModel {
    @MainActor func binding(keyPath: PartialKeyPath<State>) async { }
    @MainActor func appear() async { }
    @MainActor func firstAppear() async { }
    @MainActor func disappear() async { }
    @MainActor func handle(event: Event) { }
}

// functions for model to call
extension ComponentModel {

    @MainActor var store: ComponentStore<Self>! { _$context.store }
    @MainActor public var environment: Environment { store.environment }
    @MainActor public var dependencies: ComponentDependencies { store.dependencies }

    @MainActor
    public func mutate<Value>(_ keyPath: WritableKeyPath<State, Value>, _ value: Value, animation: Animation? = nil, file: StaticString = #filePath, line: UInt = #line) {
        store.mutate(keyPath, value: value, animation: animation, source: .capture(file: file, line: line))
    }

    @MainActor
    public func output(_ event: Output, file: StaticString = #filePath, line: UInt = #line) {
        store.output(event, source: .capture(file: file, line: line))
    }

    @MainActor
    public func outputAsync(_ event: Output, file: StaticString = #filePath, line: UInt = #line) async {
       await store.output(event, source: .capture(file: file, line: line))
    }

    @discardableResult
    @MainActor
    /// - Parameters:
    ///   - taskID: a unique id for this task. Tasks of the same id can be cancelled
    ///   - cancellable: cancel previous ongoing tasks of the same taskID
    public func task<R>(_ taskID: Task, cancellable: Bool = false, file: StaticString = #filePath, line: UInt = #line, _ task: @escaping () async -> R) async -> R {
        await store.task(taskID.taskName, cancellable: cancellable, source: .capture(file: file, line: line), task)
    }
    
    /// - Parameters:
    ///   - taskID: a unique id for this task. Tasks of the same id can be cancelled
    ///   - cancellable: cancel previous ongoing tasks of the same taskID
    ///   - catchError: This may throw a cancellation error
    @MainActor
    public func task<R>(_ taskID: Task, cancellable: Bool = false, file: StaticString = #filePath, line: UInt = #line, _ task: @escaping () async throws -> R, catch catchError: (Error) -> Void) async {
        await store.task(taskID.taskName, cancellable: cancellable, source: .capture(file: file, line: line), task, catch: catchError)
    }
    /// - Parameters:
    ///   - taskID: a unique id for this task. Tasks of the same id can be cancelled
    ///   - cancellable: cancel previous ongoing tasks of the same taskID
    @discardableResult
    @MainActor
    public func task<R>(_ taskID: Task, cancellable: Bool = false, file: StaticString = #filePath, line: UInt = #line, _ task: @escaping () async throws -> R) async throws -> R {
        try await store.task(taskID.taskName, cancellable: cancellable, source: .capture(file: file, line: line)) {
            try await task()
        }
    }
    /// Adds a task that will be cancelled upon model deinit. In comparison to `task(_)` you don't have to wait for the result making it useful for never ending tasks like AsyncStreams,
    /// and a task event will be sent as soon as the task is created
    /// - Parameters:
    ///   - taskID: a unique id for this task. Tasks of the same id can be cancelled
    ///   - cancellable: cancel previous ongoing tasks of the same taskID
    @MainActor
    public func addTask(_ taskID: Task, cancellable: Bool = false, file: StaticString = #filePath, line: UInt = #line, _ task: @escaping () async -> Void) {
        store.addTask(taskID.taskName, cancellable: cancellable, source: .capture(file: file, line: line), task)
    }

    @discardableResult
    @MainActor
    /// - Parameters:
    ///   - taskID: a unique id for this task. Tasks of the same id can be cancelled
    ///   - cancellable: cancel previous ongoing tasks of the same taskID
    public func task<R>(_ taskID: String, cancellable: Bool = false, file: StaticString = #filePath, line: UInt = #line, _ task: @escaping () async -> R) async -> R {
        await store.task(taskID, cancellable: cancellable, source: .capture(file: file, line: line), task)
    }

    /// - Parameters:
    ///   - taskID: a unique id for this task. Tasks of the same id can be cancelled
    ///   - cancellable: cancel previous ongoing tasks of the same taskID
    ///   - catchError: This may throw a cancellation error
    @MainActor
    public func task<R>(_ taskID: String, cancellable: Bool = false, file: StaticString = #filePath, line: UInt = #line, _ task: @escaping () async throws -> R, catch catchError: (Error) -> Void) async {
        await store.task(taskID, cancellable: cancellable, source: .capture(file: file, line: line), task, catch: catchError)
    }
    /// - Parameters:
    ///   - taskID: a unique id for this task. Tasks of the same id can be cancelled
    ///   - cancellable: cancel previous ongoing tasks of the same taskID
    @discardableResult
    @MainActor
    public func task<R>(_ taskID: String, cancellable: Bool = false, file: StaticString = #filePath, line: UInt = #line, _ task: @escaping () async throws -> R) async throws -> R {
        try await store.task(taskID, cancellable: cancellable, source: .capture(file: file, line: line)) {
            try await task()
        }
    }
    /// Adds a task that will be cancelled upon model deinit. In comparison to `task(_)` you don't have to wait for the result making it useful for never ending tasks like AsyncStreams
    /// and a task event will be sent as soon as the task is created
    /// - Parameters:
    ///   - taskID: a unique id for this task. Tasks of the same id can be cancelled
    ///   - cancellable: cancel previous ongoing tasks of the same taskID
    @MainActor
    public func addTask(_ taskID: String, cancellable: Bool = false, file: StaticString = #filePath, line: UInt = #line, _ task: @escaping () async -> Void) {
        store.addTask(taskID, cancellable: cancellable, source: .capture(file: file, line: line), task)
    }

    @MainActor
    public func cancelTask(_ taskID: Task) {
        store.cancelTask(cancelID: taskID.taskName)
    }

    @MainActor
    public func cancelTask(_ taskID: String) {
        store.cancelTask(cancelID: taskID)
    }

    @MainActor
    public func dismissRoute(file: StaticString = #filePath, line: UInt = #line) {
        store.dismissRoute(source: .capture(file: file, line: line))
    }

    /// dismisses the last view that rendered a body with this model
    @MainActor
    public func dismiss() {
        store.presentationMode?.wrappedValue.dismiss()
    }

    @MainActor
    public func updateView() {
        store.stateChanged.send(_$context.state)
    }

    @MainActor
    public func statePublisher() -> AnyPublisher<State, Never> {
        store.stateChanged
            .eraseToAnyPublisher()
    }

    // removes duplicates from equatable values, so only changes are published
    @MainActor
    public func statePublisher<Value: Equatable>(_ keypath: KeyPath<State, Value>) -> AnyPublisher<Value, Never> {
        statePublisher()
            .map { $0[keyPath: keypath] }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Calls a closure with any models that are currently children of this model, of a certain type. Not this closure could be called multiple times, if there are multiple models of this type
    public func childModel<Model: ComponentModel>(_ modelType: Model.Type, _ model: (Model) async -> Void) async {
        let graphStores = store.graph.getStores(for: Model.self)
        for graphStore in graphStores {
            if graphStore.path.contains(store.path), store.id != graphStore.id {
                await model(graphStore.model)
            }
        }
    }
    
    /// Calls a closure with any models that are parents of this model, of a certain type. Not this closure could be called multiple times, if there are multiple models of this type
    public func parentModel<Model: ComponentModel>(_ modelType: Model.Type, _ model: (Model) async -> Void) async {
        let graphStores = store.graph.getStores(for: Model.self)
        for graphStore in graphStores {
            if store.path.contains(graphStore.path), store.id != graphStore.id {
                await model(graphStore.model)
            }
        }
    }
    
    /// Calls a closure with any other models of a certain type. Not this closure could be called multiple times, if there are multiple models of this type
    public func otherModel<Model: ComponentModel>(_ modelType: Model.Type, _ model: (Model) async -> Void) async {
        let graphStores = store.graph.getStores(for: Model.self)
        for graphStore in graphStores {
            if store.id != graphStore.id {
                await model(graphStore.model)
            }
        }
    }
}

extension ComponentModel {
    
    /// can be used from environment closures
    public func action(_ action: Action) {
        self.store.addTask {
            await self.handle(action: action)
        }
    }
}

public struct ComponentConnection<From: ComponentModel, To: ComponentModel> {

    private let scope: (ViewModel<From>) -> ViewModel<To>
    public init(_ scope: @escaping (ViewModel<From>) -> ViewModel<To>) {
        self.scope = scope
    }

    func convert(_ from: ViewModel<From>) -> ViewModel<To> {
        scope(from)
    }
}
