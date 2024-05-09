import Foundation
import SwiftUI

@ComponentModel
struct ExampleModel {

    static let child = Connection<ExampleChildModel>(output: .input(Input.child)).connect(state: \.child)

    struct State: Equatable {
        var name: String
        var loading: Bool = false
        var date = Date()
        var child: ExampleChildModel.State?
        @Resource var resource: String?
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

    func appear() async {
        await task("get thing") {
            state.loading = false
        }
    }

    func handle(action: Action) async {
        switch action {
        case .tap(let int):
            state.date = dependencies.date()
            if #available(iOS 16, macOS 13, *) {
                try? await dependencies.continuousClock.sleep(for: .seconds(1))
            }
            output(.finished)
        case .open:
            state.child = .init(name: state.name)
            //            route(to: Route.open, state: .init(name: state.name))
            //                 .dependency(\.uuid, .constant(.init(1)))
        }
    }

    func handle(input: Input) async {
        switch input {
        case .child(.finished):
            state.child = nil
            print("Child finished")
        }
    }
}

struct ExampleView: ComponentView {

    var model: ViewModel<ExampleModel>

    var view: some View {
        if #available(iOS 16, macOS 13, *) {
            NavigationStack {
                VStack {
                    Text(model.name)
                    ProgressView().opacity(model.loading ? 1 : 0)
                    Text(model.date.formatted())
                    button(.tap(1), "Tap")
                    button(.open, "Open")
                }
                navigationDestination(item: model.presentedModel(Model.child), destination: ExampleChildView.init)
            }
        }
    }
}

@ComponentModel
struct ExampleChildModel {

    struct State: Equatable {
        var name: String
    }

    enum Action: Equatable {
        case tap(Int)
        case close
    }

    enum Output {
        case finished
    }

    func handle(action: Action) async {
        switch action {
        case .tap(let int):
            state.name += int.description
            if #available(iOS 16, macOS 13, *) {
                try? await dependencies.continuousClock.sleep(for: .seconds(1))
            }
            output(.finished)
        case .close:
            dismiss()
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

    var model: ViewModel<ExampleChildModel>

    var view: some View {
        VStack {
            Text(model.name)
            button(.tap(4)) {
                Text(model.dependencies.uuid().uuidString)
            }
            button(.close, "Close")
        }
    }
}

struct ExampleComponent: Component, PreviewProvider {
    typealias Model = ExampleModel

    static func view(model: ViewModel<ExampleModel>) -> some View {
        ExampleView(model: model)
    }

    static var preview = Snapshot(state: .init(name: "Main"))

    static var tests: Tests {
        Test("Set date", state: .init(name: "Main")) {
            let date = Date().addingTimeInterval(10000)
            Step.action(.tap(2))
                .expectState { $0.date = date }
                .dependency(\.date, .constant(date))
            Step.snapshot("tapped")
        }

        Test("Fill out", state: .init(name: "Main")) {
            Step.snapshot("empty", tags: ["empty"])
            Step.appear()
            Step.binding(\.name, "test")
                .expectTask("get thing", successful: true)
                .expectState(\.name, "invalid")
                .expectState(\.date, Date())
            Step.snapshot("filled", tags: ["featured"])
        }

        Test("Open child", state: .init(name: "Main")) {
            Step.action(.open)
            Step.connection(Model.child) {
                Step.action(.tap(4))
            }
        }
    }
}
