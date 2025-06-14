import Foundation

@MainActor
class ComponentGraph {

    var sendViewBodyEvents = false
    
    private var storesByModelType: [String: [WeakRef]] = [:]
    private var viewModelsByPath: [ComponentPath: WeakRef] = [:]
    private var routes: [ComponentPath: Any] = [:]
    let id = UUID()

    init() {

    }

    func add<Model: ComponentModel>(_ model: ViewModel<Model>) {
        viewModelsByPath[model.store.path] = WeakRef(model)
        storesByModelType[Model.name, default: []].append(.init(model.store))
    }

    func remove<Model: ComponentModel>(_ model: ViewModel<Model>) {
        remove(model.store)
    }
    
    func remove<Model: ComponentModel>(_ store: ComponentStore<Model>) {
        viewModelsByPath[store.path] = nil
        routes[store.path] = nil
        storesByModelType[Model.name]?.removeAll { ($0.value as? ComponentStore<Model>)?.id == store.id }
    }

    func getScopedModel<Model: ComponentModel, Child: ComponentModel>(model: ViewModel<Model>, child: Child.Type) -> ViewModel<Child>? {
        getModel(model.path.appending(child))
    }

    func getModel<Model: ComponentModel>(_ path: ComponentPath) -> ViewModel<Model>? {
        viewModelsByPath[path]?.value as? ViewModel<Model>
    }
    
    func getStores<Model: ComponentModel>(for model: Model.Type) -> [ComponentStore<Model>] {
        storesByModelType[Model.name]?.compactMap { $0.value as? ComponentStore<Model> } ?? []
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
