import SwiftUI
import SwiftComponent

struct ItemModel: ComponentModel {

    struct State {
        var name: String
        var text: String = "text"
        var data: Resource<Int>
        var presentDetail: ItemDetailModel.State?
        var detail: ItemDetailModel.State = .init(id: "0", name: "0")
    }

    enum Route {
        case detail(ComponentRoute<ItemDetailModel>)
    }

    enum Action {
        case calculate
        case openDetail
        case pushItem
        case updateDetail
    }

    enum Input {
        case detail(ItemDetailModel.Output)
    }

    func connect(route: Route, model: Model) -> Connection {
        switch route {
            case .detail(let route):
                return model.connect(route, output: Input.detail)
        }
    }

    func appear(model: Model) async {
        await model.loadResource(\.data) {
            try await model.dependencies.continuousClock.sleep(for: .seconds(1))
            return Int.random(in: 0...100)
        }
    }

    func handle(action: Action, model: Model) async {
        switch action {
            case .calculate:
                try? await model.dependencies.continuousClock.sleep(for: .seconds(1))
                model.name = String(UUID().uuidString.prefix(6))
            case .openDetail:
                model.presentDetail = model.detail
            case .pushItem:
                model.route(to: Route.detail, state: model.detail)
            case .updateDetail:
                model.detail.name = Int.random(in: 0...1000).description
        }
    }

    func handle(input: Input, model: Model) async {
        switch input {
            case .detail(.finished(let name)):
                model.detail.name = name
                model.name = name
                model.presentDetail = nil
        }
    }
}

struct ItemView: ComponentView {

    @ObservedObject var model: ViewModel<ItemModel>

    func presentation(for route: ItemModel.Route) -> Presentation {
        switch route {
            case .detail:
                return .push
        }
    }

    func view(route: ItemModel.Route) -> some View {
        switch route {
            case .detail(let route):
                ItemDetailView(model: route.model)
        }
    }

    var view: some View {
        VStack {
            Text(model.state.name)
            ResourceView(model.state.data) { state in
                Text(state.description)
            } error: { error in
                Text(error.localizedDescription)
            }
            .frame(height: 30)
            HStack {
                Text("Detail name: \(model.state.detail.name)")
                ActionButton(.updateDetail, "Update")
            }
            ItemDetailView(model: model.scope(state: \.detail, output: Model.Input.detail))
                .fixedSize()
            TextField("Field", text: model.binding(\.text))
                .textFieldStyle(.roundedBorder)

            ActionButton(.calculate, "Calculate")
            ActionButton(.openDetail, "Item")
            ActionButton(.pushItem, "Push Item")
            Spacer()
        }
        .padding()
        .sheet(item: model.binding(\.presentDetail)) { state in
            NavigationView {
                ItemDetailView(model: model.scope(state: \.presentDetail, value: state, output: Model.Input.detail))
            }
        }
        .navigationBarTitleDisplayMode(.large)
        .navigationTitle(Text("Item"))
    }
}

struct ItemDetailModel: ComponentModel {

    struct State: Identifiable, Equatable {
        var id: String
        var name: String
    }

    enum Action {
        case close
        case updateName
    }

    enum Output: Equatable {
        case finished(String)
    }

    func appear(model: Model) async {

    }

    func handleBinding(keyPath: PartialKeyPath<State>, model: Model) async {

    }

    func handle(action: Action, model: Model) async {
        switch action {
            case .close:
                model.output(.finished(model.name))
            case .updateName:
                model.name = Int.random(in: 0...100).description
        }
    }
}

struct ItemDetailView: ComponentView {

    @ObservedObject var model: ViewModel<ItemDetailModel>

    var view: some View {
        VStack {
            Text("Item Detail \(model.state.name)")
                .bold()
            ActionButton(.updateName) {
                Text("Update")
            }
        }
        .navigationBarTitle(Text("Item"))
        .toolbar {
            ActionButton(.close) {
                Text("Close")
            }
        }
    }
}

struct ItemComponent: Component, PreviewProvider {
    typealias Model = ItemModel

    static func view(model: ViewModel<ItemModel>) -> some View {
        ItemView(model: model)
    }

    static var preview = PreviewModel(state: .init(name: "start", data: .loading))

    static var tests: Tests {
        Test("Happy New style", state: .init(name: "john", data: .loading)) {
            Step.appear()
            Step.snapshot("loaded")
            Step.action(.updateDetail)
            Step.binding(\.text, "yeah")
                .validateState("text is set") { state in
                    state.text == "yeah"
                }
                .expectState(\.name, "yeah")
        }
    }
}
