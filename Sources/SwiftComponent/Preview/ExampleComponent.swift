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

struct ExampleComponent: ComponentModel {

    @Dependency(\.date) var now

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

    func viewTask(model: Model) async {
        await model.task("get thing") {
            model.loading = false
        }
    }
    
    func handle(input: Input, model: Model) async {
        switch input {
            case .tap(let int):
                model.date = now()
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
    typealias ModelType = ExampleComponent
    typealias ViewType = ExampleView

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
            Step.input(.tap(2))
            Step.expectState { $0.date = date }
        }

        ComponentTest("Fill out", State(name: "Main"), runViewTask: true) {
            Step.setBinding(\.name, "test")
            Step.expectState { $0.name = "invalid" }
            Step.expectState { $0.date = Date() }
        }
    }
}

#endif
