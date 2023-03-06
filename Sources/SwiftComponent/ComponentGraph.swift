import Foundation

class ComponentGraph {

    private var models: [ComponentPath: WeakRef] = [:]
    let id = UUID()

    init() {

    }

    func add<Model: ComponentModel>(_ model: ViewModel<Model>) {
        models[model.store.path] = WeakRef(model)
        //print("GRAPH", id, "add", model.store.id, model.path)
    }

    func remove<Model: ComponentModel>(_ model: ViewModel<Model>) {
        models[model.store.path] = nil
        //print("GRAPH", id, "rem", model.store.id, model.path)
    }

    func getScopedModel<Model: ComponentModel, Child: ComponentModel>(model: ViewModel<Model>, child: Child.Type) -> ViewModel<Child>? {
        getModel(model.path.appending(child))
    }

    func getModel<Model: ComponentModel>(_ path: ComponentPath) -> ViewModel<Model>? {
        let model = models[path]?.value as? ViewModel<Model>
        //print("GRAPH", id, "get", model?.store.id.description ?? "", path)
        return model
    }
}

private final class WeakRef {
    weak var value: AnyObject?

    init(_ value: AnyObject) {
        self.value = value
    }
}
