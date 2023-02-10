import Foundation

extension ComponentModelStore {

    @MainActor
    public func route<Child: ComponentModel>(to route: (ComponentRoute<Child>) -> Model.Route, state: Child.State, childRoute: Child.Route? = nil, file: StaticString = #file, line: UInt = #line) {
        store.present(route(ComponentRoute<Child>(state: state, route: childRoute)), source: .capture(file: file, line: line))
    }
}

extension ComponentModelStore {

    public func connect<Child>(_ route: ComponentRoute<Child>, file: StaticString = #file, line: UInt = #line, output toInput: @escaping (Child.Output) -> Model.Input) -> Connection {
        let childStore = ComponentStore<Child>(state: route.state, path: self.store.path, route: route.route)
        route.store = childStore
        _ = childStore.onOutput { output in
            let input = toInput(output)
            self.store.processInput(input, source: .capture(file: file, line: line))
        }
        return Connection()
    }

    public func connect<Child>(_ route: ComponentRoute<Child>, file: StaticString = #file, line: UInt = #line) -> Connection where Child.Output == Never {
        route.store = ComponentStore(state: route.state, path: self.store.path, route: route.route)
        return Connection()
    }
}


public struct Connection {

    internal init() {
        
    }
}

public class ComponentRoute<Model: ComponentModel> {

    let state: Model.State
    var route: Model.Route?
    var store: ComponentStore<Model>?
    public var viewModel: ViewModel<Model> {
        guard let store else { fatalError("store was not connected" )}
        return ViewModel(store: store)
    }

    public init(state: Model.State, route: Model.Route? = nil) {
        self.state = state
        self.route = route
    }
}

extension ComponentRoute where Model.Route == Never {

    convenience init(state: Model.State) {
        self.init(state: state, route: nil)
    }
}
