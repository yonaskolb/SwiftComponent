import Foundation
import SwiftUI
import Combine
import OSLog

@dynamicMemberLookup
public class ViewModel<Model: ComponentModel>: ObservableObject {

    let store: ComponentStore<Model>

    public var path: ComponentPath { store.path }
    public var componentName: String { Model.baseName }
    private var cancellables: Set<AnyCancellable> = []
    public var dependencies: ComponentDependencies { store.dependencies }
    public var environment: Model.Environment { store.environment }
    var sendViewBodyEvents = false

    public internal(set) var state: Model.State {
        get { store.state }
        set { store.state = newValue }
    }

    public var route: Model.Route? {
        get { store.route }
        set { store.route = newValue }
    }

    public convenience init(state: Model.State, route: Model.Route? = nil) where Model.Environment == EmptyEnvironment {
        self.init(store: .init(state: .root(state), path: nil, graph: .init(), environment: EmptyEnvironment(), route: route))
    }

    public convenience init(state: Binding<Model.State>, route: Model.Route? = nil) where Model.Environment == EmptyEnvironment {
        self.init(store: .init(state: .binding(state), path: nil, graph: .init(), environment: EmptyEnvironment(), route: route))
    }

    public convenience init(state: Model.State, environment: Model.Environment, route: Model.Route? = nil) {
        self.init(store: .init(state: .root(state), path: nil, graph: .init(), environment: environment, route: route))
    }

    public convenience init(state: Binding<Model.State>, environment: Model.Environment, route: Model.Route? = nil) {
        self.init(store: .init(state: .binding(state), path: nil, graph: .init(), environment: environment, route: route))
    }

    init(store: ComponentStore<Model>) {
        self.store = store
        self.store.stateChanged.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }
        .store(in: &cancellables)
        self.store.routeChanged.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)
        self.store.environmentChanged.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)
        store.graph.add(self)
    }

    deinit {
//        print("deinit ViewModel \(Model.baseName)")
        store.graph.remove(self)
    }

    public func onEvent(_ event: @escaping (Event) -> Void) -> Self {
        store.onEvent(event)
        return self
    }

    public func logEvents(_ events: Set<EventSimpleType> = Set(EventSimpleType.allCases).subtracting([.view]), logType: OSLogType, childEvents: Bool = true) -> Self {
        logEvents(events, logType: { _ in logType}, childEvents: childEvents)
    }

    public func logEvents(_ events: Set<EventSimpleType> = Set(EventSimpleType.allCases).subtracting([.view]), logType: ((Event) -> OSLogType?)? = nil, childEvents: Bool = true) -> Self {
        store.logEvents = events
        if let logType {
            store.logType = logType
        }
        store.logChildEvents = childEvents
        return self
    }

    public func sendViewBodyEvents(_ send: Bool = true) -> Self {
        self.sendViewBodyEvents = send
        return self
    }

    /// access state
    public subscript<Value>(dynamicMember keyPath: KeyPath<Model.State, Value>) -> Value {
        store.state[keyPath: keyPath]
    }

    /// access getters directly on a model that can access things like state, environment or dependencies
    public subscript<Value>(dynamicMember keyPath: KeyPath<Model, Value>) -> Value {
        store.model[keyPath: keyPath]
    }

    @MainActor
    public func send(_ action: Model.Action, file: StaticString = #filePath, line: UInt = #line) {
        store.processAction(action, source: .capture(file: file, line: line))
    }

    /// an async version of send. Can be used when you want to wait for the action to be handled, such as in a SwiftUI refreshable closure
    @MainActor
    // would like to use @_disfavoredOverload but doesn't seem to work when called from tests
    public func sendAsync(_ action: Model.Action, file: StaticString = #filePath, line: UInt = #line) async {
        await store.processAction(action, source: .capture(file: file, line: line))
    }

    @MainActor
    public func binding<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, file: StaticString = #filePath, line: UInt = #line) -> Binding<Value> {
        store.binding(keyPath, file: file, line: line)
    }

    @MainActor
    func appear(first: Bool, file: StaticString = #filePath, line: UInt = #line) {
        store.appear(first: first, file: file, line: line)
    }

    @MainActor
    func appearAsync(first: Bool, file: StaticString = #filePath, line: UInt = #line) async {
        await store.appear(first: first, file: file, line: line)
    }

    @MainActor
    func disappear(file: StaticString = #filePath, line: UInt = #line) {
        store.disappear(file: file, line: line)
    }

    @MainActor
    func bodyAccessed(start: Date, file: StaticString = #filePath, line: UInt = #line) {
        if sendViewBodyEvents {
            store.bodyAccessed(start: start, file: file, line: line)
        }
    }
}

// MARK: Scoping
extension ViewModel {

    // MARK: Different environment

    // state binding and output -> input
    public func scope<Child: ComponentModel>(state: Binding<Child.State>, environment: Child.Environment, output: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> {
        store.scope(state: .binding(state), environment: environment, output: .input(output)).viewModel()
    }

    // state binding and output -> output
    public func scope<Child: ComponentModel>(state: Binding<Child.State>, environment: Child.Environment, output: @escaping (Child.Output) -> Model.Output) -> ViewModel<Child> {
        store.scope(state: .binding(state), environment: environment, output: .output(output)).viewModel()
    }

    // state binding and output -> Never
    public func scope<Child: ComponentModel>(state: Binding<Child.State>, environment: Child.Environment) -> ViewModel<Child> where Child.Output == Never {
        store.scope(state: .binding(state), environment: environment).viewModel()
    }

    // statePath and output -> input
    public func scope<Child: ComponentModel>(state: WritableKeyPath<Model.State, Child.State>, environment: Child.Environment, output: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> {
        store.scope(state: .keyPath(state), environment: environment, output: .input(output)).viewModel()
    }

    // statePath and output -> output
    public func scope<Child: ComponentModel>(state: WritableKeyPath<Model.State, Child.State>, environment: Child.Environment, output: @escaping (Child.Output) -> Model.Output) -> ViewModel<Child> {
        store.scope(state: .keyPath(state), environment: environment, output: .output(output)).viewModel()
    }

    // optional statePath and output -> input
    public func scope<Child: ComponentModel>(state: WritableKeyPath<Model.State, Child.State?>, value: Child.State, environment: Child.Environment, output: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> {
        store.scope(state: .optionalKeyPath(state, fallback: value), environment: environment, output: .input(output)).viewModel()
    }

    // optional statePath and output -> output
    public func scope<Child: ComponentModel>(state: WritableKeyPath<Model.State, Child.State?>, value: Child.State, environment: Child.Environment, output: @escaping (Child.Output) -> Model.Output) -> ViewModel<Child> {
        store.scope(state: .optionalKeyPath(state, fallback: value), environment: environment, output: .output(output)).viewModel()
    }

    // optional statePath and output -> Never
    public func scope<Child: ComponentModel>(state: WritableKeyPath<Model.State, Child.State?>, value: Child.State, environment: Child.Environment) -> ViewModel<Child> where Child.Output == Never {
        store.scope(state: .optionalKeyPath(state, fallback: value), environment: environment).viewModel()
    }

    // statePath and output -> Never
    public func scope<Child: ComponentModel>(state: WritableKeyPath<Model.State, Child.State>, environment: Child.Environment) -> ViewModel<Child> where Child.Output == Never {
        store.scope(state: .keyPath(state), environment: environment).viewModel()
    }

    // state and output -> Never
    public func scope<Child: ComponentModel>(state: Child.State, environment: Child.Environment) -> ViewModel<Child> where Child.Output == Never {
        store.scope(state: .initial(state), environment: environment).viewModel()
    }

    // state and output -> input
    public func scope<Child: ComponentModel>(state: Child.State, environment: Child.Environment, output: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> {
        store.scope(state: .initial(state), environment: environment, output: .input(output)).viewModel()
    }

    // state and output -> output
    public func scope<Child: ComponentModel>(state: Child.State, environment: Child.Environment, output: @escaping (Child.Output) -> Model.Output) -> ViewModel<Child> {
        store.scope(state: .initial(state), environment: environment, output: .output(output)).viewModel()
    }

    // MARK: same environment

    // state binding and output -> input
    public func scope<Child: ComponentModel>(state: Binding<Child.State>, output: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> where Model.Environment == Child.Environment {
        store.scope(state: .binding(state), output: .input(output)).viewModel()
    }

    // state binding and output -> output
    public func scope<Child: ComponentModel>(state: Binding<Child.State>, output: @escaping (Child.Output) -> Model.Output) -> ViewModel<Child> where Model.Environment == Child.Environment {
        store.scope(state: .binding(state), output: .output(output)).viewModel()
    }

    // state binding and output -> Never
    public func scope<Child: ComponentModel>(state: Binding<Child.State>) -> ViewModel<Child> where Child.Output == Never, Model.Environment == Child.Environment {
        store.scope(state: .binding(state)).viewModel()
    }

    // statePath and output -> input
    public func scope<Child: ComponentModel>(state: WritableKeyPath<Model.State, Child.State>, output: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> where Model.Environment == Child.Environment {
        store.scope(state: .keyPath(state), output: .input(output)).viewModel()
    }

    // statePath and output -> output
    public func scope<Child: ComponentModel>(state: WritableKeyPath<Model.State, Child.State>, output: @escaping (Child.Output) -> Model.Output) -> ViewModel<Child> where Model.Environment == Child.Environment {
        store.scope(state: .keyPath(state), output: .output(output)).viewModel()
    }

    // optional statePath and output -> input
    public func scope<Child: ComponentModel>(state: WritableKeyPath<Model.State, Child.State?>, value: Child.State, output: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> where Model.Environment == Child.Environment {
        store.scope(state: .optionalKeyPath(state, fallback: value), output: .input(output)).viewModel()
    }

    // optional statePath and output -> output
    public func scope<Child: ComponentModel>(state: WritableKeyPath<Model.State, Child.State?>, value: Child.State, output: @escaping (Child.Output) -> Model.Output) -> ViewModel<Child> where Model.Environment == Child.Environment {
        store.scope(state: .optionalKeyPath(state, fallback: value), output: .output(output)).viewModel()
    }

    // optional statePath and output -> Never
    public func scope<Child: ComponentModel>(state: WritableKeyPath<Model.State, Child.State?>, value: Child.State) -> ViewModel<Child> where Child.Output == Never, Model.Environment == Child.Environment {
        store.scope(state: .optionalKeyPath(state, fallback: value)).viewModel()
    }

    // statePath and output -> Never
    public func scope<Child: ComponentModel>(state: WritableKeyPath<Model.State, Child.State>) -> ViewModel<Child> where Child.Output == Never, Model.Environment == Child.Environment {
        store.scope(state: .keyPath(state)).viewModel()
    }

    // state and output -> Never
    public func scope<Child: ComponentModel>(state: Child.State) -> ViewModel<Child> where Child.Output == Never, Model.Environment == Child.Environment {
        store.scope(state: .initial(state)).viewModel()
    }

    // state and output -> input
    public func scope<Child: ComponentModel>(state: Child.State, output: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> where Model.Environment == Child.Environment {
        store.scope(state: .initial(state), output: .input(output)).viewModel()
    }

    // state and output -> output
    public func scope<Child: ComponentModel>(state: Child.State, output: @escaping (Child.Output) -> Model.Output) -> ViewModel<Child> where Model.Environment == Child.Environment {
        store.scope(state: .initial(state), output: .output(output)).viewModel()
    }

    public func scope<Child: ComponentModel>(_ connection: ComponentConnection<Model, Child>) -> ViewModel<Child> {
        return connection.convert(self)
    }
}

extension ComponentStore {

    func viewModel() -> ViewModel<Model> {
        .init(store: self)
    }
}
