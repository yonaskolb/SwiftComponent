import Foundation
import SwiftUI
import Dependencies

struct ExampleModel: ComponentModel {

    @Dependency(\.date) var now
    @Dependency(\.timeZone) var clock

    struct State: Equatable {
        var name: String
        var loading: Bool = false
        var date = Date()
    }

    enum Action: Equatable {
        case tap(Int)
    }

    enum Output {
        case finished
    }

    enum Route {
        case open(Int)
    }

    func appear(store: Store) async {
        await store.task("get thing") {
            store.loading = false
        }
    }
    
    func handle(action: Action, store: Store) async {
        switch action {
            case .tap(let int):
                store.date = now()
                store.output(.finished)
        }
    }
}

struct ExampleChildModel: ComponentModel {

    struct State: Equatable {
        var name: String
    }
    enum Action: Equatable {
        case tap(Int)
    }
    enum Output {
        case finished
    }

    func handle(action: Action, store: Store) async {
        switch action {
            case .tap(let int):
                store.name += int.description
        }
    }
}

struct ExampleView: ComponentView {

    func routeView(_ route: ExampleModel.Route) -> some View {
        switch route {
            case .open(let id):
                Text(id.description)
        }
    }

    @ObservedObject var model: ViewModel<ExampleModel>

    var view: some View {
        VStack {
            Text(model.name)
            ProgressView().opacity(model.loading ? 1 : 0)
            Text(model.date.formatted())
            model.button(.tap(1), "Tap")
        }
    }
}

struct ExampleComponent: PreviewProvider, Component {
    typealias Model = ExampleModel

    static func view(model: ViewModel<ExampleModel>) -> some View {
        ExampleView(model: model)
    }

    static var states: States {
        State {
            .init(name: "Main")
        }
        State("Empty") {
            .init(name: "")
        }
    }

    static var routes: Routes {
        Route("thing", .open(2))
    }

    static var tests: Tests {
        Test("Sets correct date", state: .init(name: "Main"), appear: false) {
            let date = Date().addingTimeInterval(10000)
            Step.setDependency(\.date, .constant(date))
            Step.action(.tap(2))
                .expectState { $0.date = date }
        }

        Test("Fill out", state: .init(name: "Main"), appear: true) {
            Step.setBinding(\.name, "test")
                .expectState { $0.name = "invalid" }
                .expectState { $0.date = Date() }
        }
    }
}
