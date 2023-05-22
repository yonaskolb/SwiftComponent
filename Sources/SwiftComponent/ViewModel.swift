import Foundation
import SwiftUI
import Combine

@dynamicMemberLookup
public class ViewModel<Model: ComponentModel>: ObservableObject {

    let store: ComponentStore<Model>

    public var path: ComponentPath { store.path }
    public var componentName: String { Model.baseName }
    private var cancellables: Set<AnyCancellable> = []
    public var dependencies: ComponentDependencies { store.dependencies }

    public internal(set) var state: Model.State {
        get { store.state }
        set { store.state = newValue }
    }

    public var route: Model.Route? {
        get { store.route }
        set { store.route = newValue }
    }

    public convenience init(state: Model.State, route: Model.Route? = nil) {
        self.init(store: .init(state: .root(state), path: nil, graph: .init(), route: route))
    }

    public convenience init(state: Binding<Model.State>, route: Model.Route? = nil) {
        self.init(store: .init(state: .binding(state), path: nil, graph: .init(), route: route))
    }

    init(store: ComponentStore<Model>) {
        self.store = store
        self.store.stateChanged.sink { [weak self] _ in
//            DispatchQueue.main.async {
                self?.objectWillChange.send()
//            }
        }
        .store(in: &cancellables)
        self.store.routeChanged.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)
        store.graph.add(self)
    }

    deinit {
//        print("deinit ViewModel \(Model.baseName)")
        store.graph.remove(self)
    }

    public subscript<Value>(dynamicMember keyPath: KeyPath<Model.State, Value>) -> Value {
        store.state[keyPath: keyPath]
    }

    @MainActor
    public func send(_ action: Model.Action, animation: Animation? = nil, file: StaticString = #filePath, line: UInt = #line) {
        store.send(action, animation: animation, file: file, line: line)
    }

    @MainActor
    public func binding<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, file: StaticString = #filePath, line: UInt = #line, onSet: ((Value) -> Model.Action?)? = nil) -> Binding<Value> {
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
}

// MARK: Scoping
extension ViewModel {

    // state binding and output -> input
    public func scope<Child: ComponentModel>(state: Binding<Child.State>, output: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> {
        store.scope(state: .binding(state), output: .input(output)).viewModel()
    }

    // state binding and output -> output
    public func scope<Child: ComponentModel>(state: Binding<Child.State>, output: @escaping (Child.Output) -> Model.Output) -> ViewModel<Child> {
        store.scope(state: .binding(state), output: .output(output)).viewModel()
    }

    // state binding and output -> Never
    public func scope<Child: ComponentModel>(state: Binding<Child.State>) -> ViewModel<Child> where Child.Output == Never {
        store.scope(state: .binding(state)).viewModel()
    }

    // statePath and output -> input
    public func scope<Child: ComponentModel>(state: WritableKeyPath<Model.State, Child.State>, output: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> {
        store.scope(state: .keyPath(state), output: .input(output)).viewModel()
    }

    // statePath and output -> output
    public func scope<Child: ComponentModel>(state: WritableKeyPath<Model.State, Child.State>, output: @escaping (Child.Output) -> Model.Output) -> ViewModel<Child> {
        store.scope(state: .keyPath(state), output: .output(output)).viewModel()
    }

    // optional statePath and output -> input
    public func scope<Child: ComponentModel>(state: WritableKeyPath<Model.State, Child.State?>, value: Child.State, output: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> {
        store.scope(state: .optionalKeyPath(state, fallback: value), output: .input(output)).viewModel()
    }

    // optional statePath and output -> output
    public func scope<Child: ComponentModel>(state: WritableKeyPath<Model.State, Child.State?>, value: Child.State, output: @escaping (Child.Output) -> Model.Output) -> ViewModel<Child> {
        store.scope(state: .optionalKeyPath(state, fallback: value), output: .output(output)).viewModel()
    }

    // optional statePath and output -> Never
    public func scope<Child: ComponentModel>(state: WritableKeyPath<Model.State, Child.State?>, value: Child.State) -> ViewModel<Child> where Child.Output == Never {
        store.scope(state: .optionalKeyPath(state, fallback: value)).viewModel()
    }

    // statePath and output -> Never
    public func scope<Child: ComponentModel>(state: WritableKeyPath<Model.State, Child.State>) -> ViewModel<Child> where Child.Output == Never {
        store.scope(state: .keyPath(state)).viewModel()
    }

    // state and output -> Never
    public func scope<Child: ComponentModel>(state: Child.State) -> ViewModel<Child> where Child.Output == Never {
        store.scope(state: .initial(state)).viewModel()
    }

    // state and output -> input
    public func scope<Child: ComponentModel>(state: Child.State, output: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> {
        store.scope(state: .initial(state), output: .input(output)).viewModel()
    }

    // state and output -> output
    public func scope<Child: ComponentModel>(state: Child.State, output: @escaping (Child.Output) -> Model.Output) -> ViewModel<Child> {
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
