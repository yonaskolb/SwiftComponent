import SwiftUI
import SwiftComponent

@ComponentModel
struct ItemModel  {

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

    func connect(route: Route) -> Connection {
        switch route {
        case .detail(let route):
            return connect(route, output: Input.detail)
        }
    }

    func appear() async {
        await loadResource(\.data) {
            try await dependencies.continuousClock.sleep(for: .seconds(1))
            return Int.random(in: 0...100)
        }
    }

    func handle(action: Action) async {
        switch action {
        case .calculate:
            try? await dependencies.continuousClock.sleep(for: .seconds(1))
            state.name = String(UUID().uuidString.prefix(6))
        case .openDetail:
            state.presentDetail = state.detail
        case .pushItem:
            route(to: Route.detail, state: state.detail)
        case .updateDetail:
            state.detail.name = Int.random(in: 0...1000).description
        }
    }

    func handle(input: Input) async {
        switch input {
        case .detail(.finished(let name)):
            state.detail.name = name
            state.name = name
            state.presentDetail = nil
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
                button(.updateDetail, "Update")
            }
            ItemDetailView(model: model.scope(state: \.detail, output: Model.Input.detail))
                .fixedSize()
            TextField("Field", text: model.binding(\.text))
                .textFieldStyle(.roundedBorder)

            button(.calculate, "Calculate")
            button(.openDetail, "Item")
            button(.pushItem, "Push Item")
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

@ComponentModel
struct ItemDetailModel {

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

    func appear() async {

    }

    func binding(keyPath: PartialKeyPath<State>) async {

    }

    func handle(action: Action) async {
        switch action {
        case .close:
            output(.finished(state.name))
        case .updateName:
            state.name = Int.random(in: 0...100).description
        }
    }
}

struct ItemDetailView: ComponentView {

    @ObservedObject var model: ViewModel<ItemDetailModel>

    var view: some View {
        VStack {
            Text("Item Detail \(model.state.name)")
                .bold()
            button(.updateName) {
                Text("Update")
            }
        }
        .navigationBarTitle(Text("Item"))
        .toolbar {
            button(.close) {
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
