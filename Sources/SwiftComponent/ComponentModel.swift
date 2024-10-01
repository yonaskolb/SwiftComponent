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
    associatedtype Task: ModelTask = String
    associatedtype Environment: ComponentEnvironment = EmptyEnvironment
    associatedtype Connections = Void
    @MainActor func appear() async
    @MainActor func firstAppear() async
    @MainActor func disappear() async
    @MainActor func binding(keyPath: PartialKeyPath<State>) async
    @MainActor func handle(action: Action) async
    @MainActor func handle(input: Input) async
    var _$connections: Connections { get }
    nonisolated func handle(event: Event)
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
extension String: ModelTask {
    public var taskName: String { self }
}

extension RawRepresentable where RawValue == String {
    public var taskName: String { rawValue }
}

extension ComponentModel {
    
    public var state: Context { _$context }
    
    var connections: Connections { _$connections}

    nonisolated
    public static var baseName: String {
        var name = String(describing: Self.self)
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
    func connect(route: Route) -> RouteConnection { RouteConnection() }
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

    @discardableResult
    @MainActor
    public func task<R>(_ taskID: Task, cancellable: Bool = false, file: StaticString = #filePath, line: UInt = #line, _ task: @escaping () async -> R) async -> R {
        await store.task(taskID.taskName, cancellable: cancellable, source: .capture(file: file, line: line), task)
    }

    @MainActor
    public func task<R>(_ taskID: Task, cancellable: Bool = false, file: StaticString = #filePath, line: UInt = #line, _ task: @escaping () async throws -> R, catch catchError: (Error) -> Void) async {
        await store.task(taskID.taskName, cancellable: cancellable, source: .capture(file: file, line: line), task, catch: catchError)
    }

    @discardableResult
    @MainActor
    public func task<R>(_ taskID: Task, cancellable: Bool = false, file: StaticString = #filePath, line: UInt = #line, _ task: @escaping () async throws -> R) async throws -> R {
        try await store.task(taskID.taskName, cancellable: cancellable, source: .capture(file: file, line: line)) {
            try await task()
        }
    }

    @MainActor
    public func cancelTask(_ taskID: Task) {
        store.cancelTask(cancelID: taskID.taskName)
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
