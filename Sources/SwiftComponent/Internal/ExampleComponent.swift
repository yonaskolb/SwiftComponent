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

    func appear(model: Model) async {
        await model.task("get thing") {
            model.loading = false
        }
    }

    func connect(route: Route, model: Model) -> Connection {
        switch route {
        case .open(let route):
            return model.connect(route, output: Input.child)
        }
    }

    func handle(action: Action, model: Model) async {
        switch action {
            case .tap(let int):
                model.date = model.dependencies.date()
                model.output(.finished)
            case .open:
                model.route(to: Route.open, state: .init(name: model.name))
                     .dependency(\.uuid, .constant(.init(1)))
        }
    }

    func handle(input: Input, model: Model) async {
        switch input {
        case .child(let output): break
        }
    }
}

struct ExampleView: ComponentView {

    @ObservedObject var model: ViewModel<ExampleModel>

    func view(route: ExampleModel.Route) -> some View {
        switch route {
            case .open(let route):
                ExampleChildView(model: route.model)
        }
    }

    var view: some View {
        VStack {
            Text(model.name)
            ProgressView().opacity(model.loading ? 1 : 0)
            Text(model.date.formatted())
            button(.tap(1), "Tap")
            button(.open, "Open")
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

    func handle(action: Action, model: Model) async {
        switch action {
            case .tap(let int):
                model.name += int.description
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

    static var preview = Snapshot(state: .init(name: "Main"))

    static var routes: Routes {
        Route("thing", .open(.init(state: .init(name: "routeds"))))
    }

    static var tests: Tests {
        Test("Set date", state: .init(name: "Main")) {
            let date = Date().addingTimeInterval(10000)
            Step.action(.tap(2))
                .expectState { $0.date = date }
                .dependency(\.date, .constant(date))
            Step.snapshot("tapped")
        }

        Test("Fill out", state: .init(name: "Main")) {
            Step.snapshot("empty")
            Step.appear()
            Step.binding(\.name, "test")
                .expectTask("get thing", successful: true)
                .expectState(\.name, "invalid")
                .expectState(\.date, Date())
            Step.snapshot("filled")
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
