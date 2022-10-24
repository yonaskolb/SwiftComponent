//
//  File.swift
//  
//
//  Created by Yonas Kolb on 21/10/2022.
//

import Foundation
import SwiftUI
import Dependencies

#if DEBUG

struct ExampleComponent: Component {

    @Dependency(\.date) var now

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

    func task(model: Model) async {
        await model.task("get thing") {
            model.loading = false
        }
    }
    
    func handle(action: Action, model: Model) async {
        switch action {
            case .tap(let int):
                model.date = now()
        }
    }
}

struct ExampleSubComponent: Component {

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
}

struct ExampleView: ComponentView {

    @ObservedObject var model: ViewModel<ExampleComponent>

    var view: some View {
        VStack {
            Text(model.name)
            ProgressView().opacity(model.loading ? 1 : 0)
            Text(model.date.formatted())
            model.actionButton(.tap(1), "Tap")
        }
    }
}

struct ExamplePreview: PreviewProvider, ComponentPreview {
    typealias ComponentType = ExampleComponent
    typealias ComponentViewType = ExampleView

    static var states: [ComponentState] {
        ComponentState {
            State(name: "Main")
        }
        ComponentState("Empty") {
            State(name: "")
        }
    }

    static var tests: [ComponentTest] {
        ComponentTest("Sets correct date", State(name: "Main"), runViewTask: false) {
            let date = Date().addingTimeInterval(10000)
            Step.setDependency(\.date, .constant(date))
            Step.sendAction(.tap(2))
            Step.expectState { $0.date = date }
        }

        ComponentTest("Fill out", State(name: "Main"), runViewTask: true) {
            Step.setBinding(\.name, "test")
        }
    }
}

#endif
