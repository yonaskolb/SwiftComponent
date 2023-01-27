import Foundation
import SwiftUI
import Dependencies

struct ExampleComponent: ComponentModel {

    @Dependency(\.date) var now
    @Dependency(\.timeZone) var clock

    struct State: Equatable {
        var name: String
        var loading: Bool = false
        var date = Date()
    }

    enum Input: Equatable {
        case tap(Int)
    }

    enum Output {
        case finished
    }

    enum Route {
        case open(Int)
    }

    func appear(model: Model) async {
        await model.task("get thing") {
            model.loading = false
        }
    }
    
    func handle(input: Input, model: Model) async {
        switch input {
            case .tap(let int):
                model.date = now()
                model.output(.finished)
        }
    }
}

struct ExampleSubComponent: ComponentModel {

    struct State: Equatable {
        var name: String
    }
    enum Input: Equatable {
        case tap(Int)
    }
    enum Output {
        case finished
    }

    func handle(input: Input, model: Model) async {
        switch input {
            case .tap(let int):
                model.name += int.description
        }
    }
}

struct ExampleView: ComponentView {

    func routeView(_ route: ExampleComponent.Route) -> some View {
        switch route {
            case .open(let id):
                Text(id.description)
        }
    }


    @ObservedObject var model: ViewModel<ExampleComponent>

    var view: some View {
        VStack {
            Text(model.name)
            ProgressView().opacity(model.loading ? 1 : 0)
            Text(model.date.formatted())
            model.inputButton(.tap(1), "Tap")
        }
    }
}

struct ExamplePreview: PreviewProvider, ComponentFeature {
    typealias Model = ExampleComponent

    static func createView(model: ViewModel<ExampleComponent>) -> some View {
        ExampleView(model: model)
    }

    static var states: [ComponentState] {
        ComponentState {
            State(name: "Main")
        }
        ComponentState("Empty") {
            State(name: "")
        }
    }

    static var routes: [ComponentRoute] {
        ComponentRoute("thing", .open(2))
    }

    static var tests: [ComponentTest] {
        ComponentTest("Sets correct date", state: State(name: "Main"), appear: false) {
            let date = Date().addingTimeInterval(10000)
            Step.setDependency(\.date, .constant(date))
            Step.input(.tap(2))
                .expectState { $0.date = date }
        }

        ComponentTest("Fill out", state: State(name: "Main"), appear: true) {
            Step.setBinding(\.name, "test")
                .expectState { $0.name = "invalid" }
                .expectState { $0.date = Date() }
        }
    }
}
