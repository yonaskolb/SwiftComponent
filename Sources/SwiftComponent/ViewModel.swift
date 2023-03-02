import Foundation
import SwiftUI
import Combine

@dynamicMemberLookup
public class ViewModel<Model: ComponentModel>: ObservableObject {

    let store: ComponentStore<Model>

    public var path: ComponentPath { store.path }
    public var componentName: String { Model.baseName }
    private var cancellables: Set<AnyCancellable> = []

    public internal(set) var state: Model.State {
        get { store.state }
        set { store.state = newValue }
    }

    public var route: Model.Route? {
        get { store.route }
        set { store.route = newValue }
    }

    public convenience init(state: Model.State, route: Model.Route? = nil) {
        self.init(store: .init(state: state, route: route))
    }

    public convenience init(state: Binding<Model.State>, route: Model.Route? = nil) {
        self.init(store: .init(state: state, route: route))
    }

    init(store: ComponentStore<Model>) {
        self.store = store
        self.store.stateChanged.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)
        self.store.routeChanged.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)
    }

    public subscript<Value>(dynamicMember keyPath: KeyPath<Model.State, Value>) -> Value {
        store.state[keyPath: keyPath]
    }

    public func send(_ action: Model.Action, animation: Animation? = nil, file: StaticString = #file, line: UInt = #line) {
        store.send(action, animation: animation, file: file, line: line)
    }

    @MainActor
    public func binding<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, file: StaticString = #file, line: UInt = #line, onSet: ((Value) -> Model.Action?)? = nil) -> Binding<Value> {
        store.binding(keyPath, file: file, line: line)
    }

    @MainActor
    public func appear(first: Bool, file: StaticString = #file, line: UInt = #line) async {
        await store.appear(first: first, file: file, line: line)
    }
}

// MARK: Scoping
extension ViewModel {

    // state binding and output
    public func scope<Child: ComponentModel>(state: Binding<Child.State>, file: StaticString = #file, line: UInt = #line, output toInput: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> {
        store.scope(state: state, file: file, line: line, output: toInput).viewModel()
    }

    // state binding
    public func scope<Child: ComponentModel>(state: Binding<Child.State>) -> ViewModel<Child> where Child.Output == Never {
        store.scope(state: state).viewModel()
    }

    // statePath and output
    public func scope<Child: ComponentModel>(statePath: WritableKeyPath<Model.State, Child.State>, file: StaticString = #file, line: UInt = #line, output toInput: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> {
        store.scope(statePath: statePath, file: file, line: line, output: toInput).viewModel()
    }

    // optional statePath and output
    public func scope<Child: ComponentModel>(statePath: WritableKeyPath<Model.State, Child.State?>, value: Child.State, file: StaticString = #file, line: UInt = #line, output toInput: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> {
        store.scope(statePath: statePath, value: value, file: file, line: line, output: toInput).viewModel()
    }

    // optional statePath
    public func scope<Child: ComponentModel>(statePath: WritableKeyPath<Model.State, Child.State?>, value: Child.State) -> ViewModel<Child> where Child.Output == Never {
        store.scope(statePath: statePath, value: value).viewModel()
    }

    // statePath
    public func scope<Child: ComponentModel>(statePath: WritableKeyPath<Model.State, Child.State>) -> ViewModel<Child> where Child.Output == Never {
        store.scope(statePath: statePath).viewModel()
    }

    // state
    public func scope<Child: ComponentModel>(state: Child.State) -> ViewModel<Child> where Child.Output == Never {
        store.scope(state: state).viewModel()
    }

    // state and output
    public func scope<Child: ComponentModel>(state: Child.State, file: StaticString = #file, line: UInt = #line, output toInput: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> {
        store.scope(state: state, file: file, line: line, output: toInput).viewModel()
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
