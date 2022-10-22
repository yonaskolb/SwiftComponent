//
//  File.swift
//  
//
//  Created by Yonas Kolb on 21/10/2022.
//

import Foundation
import SwiftUI

#if DEBUG

struct ExampleComponent: Component {

    struct State: Equatable {
        var name: String
        var loaded: Bool = false
    }
    enum Action: Equatable {
        case tap(UUID)
    }
    enum Output {
        case finished
    }

    func task(model: Model) async {
        model.loaded = true
    }
    
    func handle(action: Action, model: Model) async {

    }
}

struct ExampleSubComponent: Component {

    struct State: Equatable {
        var name: String
    }
    enum Action: Equatable {
        case tap(UUID)
    }
    enum Output {
        case finished
    }

    func handle(action: Action, model: Model) async {

    }
}

struct ExampleView: ComponentView {

    @ObservedObject var model: ViewModel<ExampleComponent>

    var view: some View {
        VStack {
            Text(model.name)
            ProgressView().opacity(model.loaded ? 0 : 1)
        }
    }
}

struct ExamplePreview: PreviewProvider, ComponentPreview {
    typealias ComponentType = ExampleComponent
    typealias ComponentViewType = ExampleView

    static var states: [ComponentState] {
        ComponentState {
            .init(name: "Main")
        }
        ComponentState("Empty") {
            .init(name: "")
        }
    }

    static var tests: [ComponentTest] {
        ComponentTest("Sets name", .init(name: "Main"), steps: [
            .action(.tap(UUID())),
            .setBinding(\.name, "test"),
//            .validateState { state in
//                state.name == "test2"
//            },
            .expectState { state in
                state.name = "test2"
            }
        ])
    }
}

#endif
