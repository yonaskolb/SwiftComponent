import Foundation

extension ComponentModel {

    @MainActor
    @discardableResult
    public func route<Child: ComponentModel>(to route: (ComponentRoute<Child>) -> Route, state: Child.State, childRoute: Child.Route? = nil, file: StaticString = #filePath, line: UInt = #line) -> ComponentRoute<Child> {
        let componentRoute = ComponentRoute<Child>(state: state, route: childRoute)
        store.present(route(componentRoute), source: .capture(file: file, line: line))
        return componentRoute
    }
}

extension ComponentModel {

    // MARK: different environment

    public func connect<Child>(_ route: ComponentRoute<Child>, environment: Child.Environment, output toInput: @escaping (Child.Output) -> Input) -> Connection {
        route.setStore(store.scope(state: .initial(route.state), environment: environment, route: route.route, output: .input(toInput)))
        return Connection()
    }

    public func connect<Child>(_ route: ComponentRoute<Child>, environment: Child.Environment, output toOutput: @escaping (Child.Output) -> Output) -> Connection {
        route.setStore(store.scope(state: .initial(route.state), environment: environment, route: route.route, output: .output(toOutput)))
        return Connection()
    }

    public func connect<Child>(_ route: ComponentRoute<Child>, environment: Child.Environment) -> Connection where Child.Output == Never {
        route.setStore(store.scope(state: .initial(route.state), environment: environment, route: route.route))
        return Connection()
    }

    public func connect<Child: ComponentModel>(_ route: ComponentRoute<Child>, scope: Scope<Child>, environment: Child.Environment) -> Connection {
        let routeViewModel = scope.convert(store.viewModel())
        route.setStore(routeViewModel.store)
        return Connection()
    }

    // MARK: same environment

    public func connect<Child>(_ route: ComponentRoute<Child>, output toInput: @escaping (Child.Output) -> Input) -> Connection where Environment == Child.Environment {
        route.setStore(store.scope(state: .initial(route.state), route: route.route, output: .input(toInput)))
        return Connection()
    }

    public func connect<Child>(_ route: ComponentRoute<Child>, output toOutput: @escaping (Child.Output) -> Output) -> Connection where Environment == Child.Environment {
        route.setStore(store.scope(state: .initial(route.state), route: route.route, output: .output(toOutput)))
        return Connection()
    }

    public func connect<Child>(_ route: ComponentRoute<Child>) -> Connection where Child.Output == Never, Environment == Child.Environment {
        route.setStore(store.scope(state: .initial(route.state), route: route.route))
        return Connection()
    }

    public func connect<Child: ComponentModel>(_ route: ComponentRoute<Child>, scope: Scope<Child>) -> Connection where Environment == Child.Environment {
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
    public var model: ViewModel<Model> {
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

@resultBuilder
public struct RouteBuilder {
    public static func buildBlock<Route>() -> [ComponentModelRoute<Route>] { [] }
    public static func buildBlock<Route>(_ routes: ComponentModelRoute<Route>...) -> [ComponentModelRoute<Route>] { routes }
    public static func buildBlock<Route>(_ routes: [ComponentModelRoute<Route>]) -> [ComponentModelRoute<Route>] { routes }
}

public struct ComponentModelRoute<Route> {
    public let name: String
    public let route: Route
    public init(_ name: String, _ route: Route) {
        self.name = name
        self.route = route
    }
}
