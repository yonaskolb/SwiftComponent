import Foundation

class ComponentGraph {

    var sendViewBodyEvents = false
    
    private var models: [ComponentPath: WeakRef] = [:]
    private var routes: [ComponentPath: Any] = [:]
    let id = UUID()

    init() {

    }

    func add<Model: ComponentModel>(_ model: ViewModel<Model>) {
        models[model.store.path] = WeakRef(model)
    }

    func remove<Model: ComponentModel>(_ model: ViewModel<Model>) {
        models[model.store.path] = nil
        routes[model.store.path] = nil
    }

    func getScopedModel<Model: ComponentModel, Child: ComponentModel>(model: ViewModel<Model>, child: Child.Type) -> ViewModel<Child>? {
        getModel(model.path.appending(child))
    }

    func getModel<Model: ComponentModel>(_ path: ComponentPath) -> ViewModel<Model>? {
        models[path]?.value as? ViewModel<Model>
    }

    func addRoute<Model: ComponentModel>(store: ComponentStore<Model>, route: Model.Route) {
        routes[store.path] = route
    }

    func removeRoute<Model: ComponentModel>(store: ComponentStore<Model>) {
        routes[store.path] = nil
    }

    func getRoute<Model: ComponentModel>(store: ComponentStore<Model>) -> Model.Route? {
        routes[store.path] as? Model.Route
    }

    func clearRoutes() {
        routes.removeAll()
    }
}

final class WeakRef {
    weak var value: AnyObject?

    init(_ value: AnyObject) {
        self.value = value
    }
}
