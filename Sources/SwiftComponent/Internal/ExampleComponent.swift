import Foundation
import SwiftUI

struct ExampleModel: ComponentModel {

    struct State: Equatable {
        var name: String
        var loading: Bool = false
        var date = Date()
    }

    enum Action: Equatable {
        case tap(Int)
        case open
    }

    enum Output {
        case finished
        case unhandled
    }

    enum Input {
        case child(ExampleChildModel.Output)
    }

    enum Route {
        case open(ComponentRoute<ExampleChildModel>)
    }

    func appear(store: Store) async {
        await store.task("get thing") {
            store.loading = false
        }
    }

    func connect(route: Route, store: Store) -> Connection {
        switch route {
        case .open(let route):
            return store.connect(route, output: Input.child)
        }
    }

    func handle(action: Action, store: Store) async {
        switch action {
            case .tap(let int):
                store.date = store.dependencies.date()
                store.output(.finished)
            case .open:
                store.route(to: Route.open, state: .init(name: store.name))
                     .dependency(\.uuid, .constant(.init(1)))
        }
    }

    func handle(input: Input, store: Store) async {
        switch input {
        case .child(let output): break
        }
    }
}

struct ExampleView: ComponentView {

    @ObservedObject var model: ViewModel<ExampleModel>

    func routeView(_ route: ExampleModel.Route) -> some View {
        switch route {
            case .open(let route):
                ExampleChildView(model: route.viewModel)
        }
    }

    var view: some View {
        VStack {
            Text(model.name)
            ProgressView().opacity(model.loading ? 1 : 0)
            Text(model.date.formatted())
            model.button(.tap(1), "Tap")
            model.button(.open, "Open")
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

    func handle(event: Event) {
        event.forModel(ExampleChildModel.self) { event in
            switch event {
                case .output(let output):
                    switch output {
                        case .finished:
                            break
                    }
                default: break
            }
        }
    }
}


struct ExampleChildView: ComponentView {

    @ObservedObject var model: ViewModel<ExampleChildModel>

    var view: some View {
        VStack {
            Text(model.name)
            Text(model.dependencies.uuid().uuidString)
        }
    }
}

struct ExampleComponent: Component, PreviewProvider {
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
        Route("thing", .open(.init(state: .init(name: "routeds"))))
    }

    static var tests: Tests {
        Test("Set date", state: .init(name: "Main")) {
            let date = Date().addingTimeInterval(10000)
            Step.dependency(\.date, .constant(date))
            Step.action(.tap(2))
                .expectState { $0.date = date }
        }

        Test("Fill out", state: .init(name: "Main")) {
            Step.appear()
            Step.binding(\.name, "test")
                .expectTask("get thing", successful: true)
                .expectState(\.name, "invalid")
                .expectState(\.date, Date())
        }

        Test("Open child", state: .init(name: "Main"), assertions: [.output]) {
            Step.action(.open)
                .expectRoute(/Model.Route.open, state: .init(name: "Main"))
            Step.route(/Model.Route.open) {
                Step.action(.tap(2))
            }
        }
    }
}
