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

    func connect(route: Route, store: Store) -> Connection {
        switch route {
            case .detail(let route):
                return store.connect(route, output: Input.detail)
        }
    }

    func appear(store: Store) async {
        await store.loadResource(\.data) {
            try await clock.sleep(for: .seconds(1))
            return Int.random(in: 0...100)
        }
    }

    func handle(action: Action, store: Store) async {
        switch action {
            case .calculate:
                try? await store.dependencies.continuousClock.sleep(for: .seconds(1))
                store.name = String(UUID().uuidString.prefix(6))
            case .openDetail:
                store.presentDetail = store.detail
            case .pushItem:
                store.route(to: Route.detail, state: store.detail)
            case .updateDetail:
                store.detail.name = Int.random(in: 0...1000).description
        }
    }

    func handle(input: Input, store: Store) async {
        switch input {
            case .detail(.finished(let name)):
                store.detail.name = name
                store.name = name
                store.presentDetail = nil
        }
    }

    func handleBinding(keyPath: PartialKeyPath<State>, store: Store) async {
        switch keyPath {
            case \.name:
                print("changed name")
            default:
                break
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

    func routeView(_ route: ItemModel.Route) -> some View {
        switch route {
            case .detail(let route):
                ItemDetailView(model: route.viewModel)
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
                model.button(.updateDetail, "Update")
            }
            ItemDetailView(model: model.scope(statePath: \.detail, output: Model.Input.detail))
                .fixedSize()
            TextField("Field", text: model.binding(\.text))
                .textFieldStyle(.roundedBorder)

            model.button(.calculate, "Calculate")
            model.button(.openDetail, "Item")
            model.button(.pushItem, "Push Item")
            Spacer()
        }
        .padding()
        .sheet(item: model.binding(\.presentDetail)) { state in
            NavigationView {
                ItemDetailView(model: model.scope(statePath: \.presentDetail, value: state, output: Model.Input.detail))
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

    func appear(store: Store) async {

    }

    func handleBinding(keyPath: PartialKeyPath<State>, store: Store) async {

    }

    func handle(action: Action, store: Store) async {
        switch action {
            case .close:
                store.output(.finished(store.name))
            case .updateName:
                store.name = Int.random(in: 0...100).description
        }
    }
}

struct ItemDetailView: ComponentView {

    @ObservedObject var model: ViewModel<ItemDetailModel>

    var view: some View {
        VStack {
            Text("Item Detail \(model.state.name)")
                .bold()
            Button(action: { model.send(.updateName)}) {
                Text("Update")
            }
        }
        .navigationBarTitle(Text("Item"))
        .toolbar {
            Button(action: { model.send(.close) }) {
                Text("Close")
            }
        }
    }
}

struct ItemComponent: PreviewProvider, Component {
    typealias Model = ItemModel

    static func view(model: ViewModel<ItemModel>) -> some View {
        ItemView(model: model)
    }

    static var states: States {
        State {
            .init(name: "start", data: .loading)
        }

        State("Loaded") {
            .init(name: "Loaded", data: .content(2))
        }
    }

    static var tests: Tests {
        Test("Happy New style", state: .init(name: "john", data: .loading)) {
            Step.action(.updateDetail)
            Step.setBinding(\.text, "yeah")
                .validateState("text is set") { state in
                    state.text == "yeah"
                }
                .expectState { state in
                    state.name = "yeah"
                }
        }
    }
}
