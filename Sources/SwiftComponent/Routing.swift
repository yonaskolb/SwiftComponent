import Foundation

extension ComponentModelStore {

    @MainActor
    @discardableResult
    public func route<Child: ComponentModel>(to route: (ComponentRoute<Child>) -> Model.Route, state: Child.State, childRoute: Child.Route? = nil, file: StaticString = #file, line: UInt = #line) -> ComponentRoute<Child> {
        let componentRoute = ComponentRoute<Child>(state: state, route: childRoute)
        store.present(route(componentRoute), source: .capture(file: file, line: line))
        return componentRoute
    }
}

extension ComponentModelStore {

    public func connect<Child>(_ route: ComponentRoute<Child>, file: StaticString = #file, line: UInt = #line, output toInput: @escaping (Child.Output) -> Model.Input) -> Connection {
        let childStore = ComponentStore<Child>(state: route.state, path: self.store.path, graph: self.store.graph, route: route.route)
        route.setStore(childStore)
        _ = childStore.onOutput { output in
            let input = toInput(output)
            self.store.processInput(input, source: .capture(file: file, line: line))
        }
        return Connection()
    }

    public func connect<Child>(_ route: ComponentRoute<Child>, file: StaticString = #file, line: UInt = #line) -> Connection where Child.Output == Never {
        route.setStore(ComponentStore(state: route.state, path: self.store.path, graph: self.store.graph, route: route.route))
        return Connection()
    }

    public func connect<Child: ComponentModel>(_ route: ComponentRoute<Child>, scope: Model.Scope<Child>) -> Connection {
        let routeViewModel = scope.convert(store.viewModel())
        route.setStore(routeViewModel.store)
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
    var dependencies: ComponentDependencies
    var store: ComponentStore<Model>?
    public var viewModel: ViewModel<Model> {
        guard let store else { fatalError("store was not connected" )}
        return ViewModel(store: store)
    }

    public init(state: Model.State, route: Model.Route? = nil) {
        self.state = state
        self.route = route
        self.dependencies = .init()
    }

    func setStore(_ store: ComponentStore<Model>) {
        self.store = store
        store.dependencies.apply(dependencies)
    }
}

extension ComponentRoute where Model.Route == Never {

    convenience init(state: Model.State) {
        self.init(state: state, route: nil)
    }
}
