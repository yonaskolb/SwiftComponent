import Foundation
import SwiftUI

@dynamicMemberLookup
public class ViewModel<Model: ComponentModel>: ObservableObject {

    let store: ComponentStore<Model>

    public var path: ComponentPath { store.path }
    public var componentName: String { Model.baseName }

    var state: Model.State {
        get { store.state }
        set { store.state = newValue }
    }

    var route: Model.Route? {
        get { store.route }
        set { store.route = newValue }
    }

    public convenience init(state: Model.State) {
        self.init(store: .init(state: state))
    }

    public convenience init(state: Binding<Model.State>) {
        self.init(store: .init(state: state))
    }

    init(store: ComponentStore<Model>) {
        self.store = store
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
    public func appear(first: Bool) async {
        await store.appear(first: first)
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
}

extension ComponentStore {

    func viewModel() -> ViewModel<Model> {
        .init(store: self)
    }
}
