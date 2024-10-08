import SwiftUI
import SwiftComponent

@ComponentModel
struct ItemModel  {

    struct Connections {
        let detail = Connection<ItemDetailModel>(output: .input(Input.detail))
            .connect(state: \.detail)
        
        let presentedDetail = Connection<ItemDetailModel>(output: .input(Input.detail))
            .connect(state: \.destination, case: \.detail)
    }
    
    struct State {
        var name: String
        var text: String = "text"
        var unreadProperty = 0
        @Resource var data: Int?
        var presentedDetail: ItemDetailModel.State?
        var detail: ItemDetailModel.State = .init(id: "0", name: "0")
        var destination: Destination?
    }
    
    enum Route {
        case detail(ComponentRoute<ItemDetailModel>)
    }

    enum Destination {
        case detail(ItemDetailModel.State)
    }

    enum Action {
        case calculate
        case present
        case push
        case updateDetail
        case updateUnread
    }

    enum Input {
        case detail(ItemDetailModel.Output)
    }

    func connect(route: Route) -> RouteConnection {
        switch route {
        case .detail(let route):
            return connect(route, output: Input.detail)
        }
    }

    func appear() async {
        await loadResource(\.$data) {
            try await dependencies.continuousClock.sleep(for: .seconds(1))
            return Int.random(in: 0...100)
        }
    }

    func handle(action: Action) async {
        switch action {
        case .calculate:
            try? await dependencies.continuousClock.sleep(for: .seconds(1))
            state.name = String(UUID().uuidString.prefix(6))
        case .present:
            state.presentedDetail = state.detail
        case .push:
//            route(to: Route.detail, state: state.detail)
            state.destination = .init(.detail(state.detail))
        case .updateDetail:
            state.detail.name = Int.random(in: 0...1000).description
        case .updateUnread:
            state.unreadProperty += 1
        }
    }

    func handle(input: Input) async {
        switch input {
        case .detail(.finished(let name)):
            state.detail.name = name
            state.name = name
            state.presentedDetail = nil
        }
    }
}

struct ItemView: ComponentView {

    var model: ViewModel<ItemModel>

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
            ResourceView(model.state.$data) { state in
                Text(state.description)
            } error: { error in
                Text(error.localizedDescription)
            }
            .frame(height: 30)
            HStack {
                Text("Detail name: \(model.state.detail.name)")
                button(.updateDetail, "Update Detail")
            }
            ItemDetailView(model: model.connectedModel(\.detail))
                .fixedSize()
            TextField("Field", text: model.binding(\.text))
                .textFieldStyle(.roundedBorder)

            button(.calculate, "Calculate")
            button(.updateUnread, "Update unread")
            button(.present, "Item")
            button(.push, "Push Item")
            Spacer()
        }
        .padding()
        .navigationDestination(item: model.presentedModel(\.presentedDetail)) { model in
            ItemDetailView(model: model)
                .toolbar {
                    button(.updateDetail) {
                        Text("Save")
                    }
                }
        }
    }
}

@ComponentModel
struct ItemDetailModel {

    struct State: Identifiable, Equatable {
        var id: String
        var name: String
    }

    enum Action {
        case save
        case updateName
    }

    enum Output: Equatable {
        case finished(String)
    }

    func appear() async {

    }

    func binding(keyPath: PartialKeyPath<State>) async {
        
    }

    func handle(action: Action) async {
        switch action {
        case .save:
            output(.finished(state.name))
            dismiss()
        case .updateName:
            state.name = Int.random(in: 0...100).description
        }
    }
}

struct ItemDetailView: ComponentView {

    var model: ViewModel<ItemDetailModel>

    var view: some View {
        VStack {
            Text("Item Detail \(model.state.name)")
                .bold()
            button(.updateName) {
                Text("Update name")
            }
        }
    }
}

struct ItemComponent: Component, PreviewProvider {
    typealias Model = ItemModel

    static func view(model: ViewModel<ItemModel>) -> some View {
        ItemView(model: model.sendViewBodyEvents())
    }

    static var preview = PreviewModel(state: .init(name: "start"))

    static var tests: Tests {
        Test(state: .init(name: "john")) {
            Step.appear()
                .expectResourceTask(\.$data)
            Step.snapshot("loaded")
            Step.action(.updateDetail)
            Step.binding(\.text, "yeah")
        }
    }
}
