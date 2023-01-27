//
//  ContentView.swift
//  Example
//
//  Created by Yonas Kolb on 1/10/2022.
//

import SwiftUI
import SwiftComponent

struct ItemComponent: ComponentModel {

    @Dependency(\.continuousClock) var clock

    struct State {
        var name: String
        var text: String = "text"
        var data: Resource<Int>
        var presentDetail: ItemDetailComponent.State?
        var detail: ItemDetailComponent.State = .init(id: "0", name: "0")
    }

    enum Route {
        case detail(ItemDetailComponent.State)
    }

    enum Input {
        case calculate
        case openDetail
        case pushItem
        case detail(ItemDetailComponent.Output)
        case updateDetail
    }

    func appear(model: Model) async {
        await model.loadResource(\.data) {
            try await clock.sleep(for: .seconds(1))
            return Int.random(in: 0...100)
        }
    }

    func handle(input: Input, model: Model) async {
        switch input {
            case .calculate:
                try? await clock.sleep(for: .seconds(1))
                model.name = String(UUID().uuidString.prefix(6))
            case .openDetail:
                model.presentDetail = model.detail
            case .pushItem:
                model.present(.detail(model.detail))
            case .detail(.finished(let name)):
                model.detail.name = name
                model.name = name
                model.presentDetail = nil
            case .updateDetail:
                model.detail.name = Int.random(in: 0...1000).description
        }
    }

    func handleBinding(keyPath: PartialKeyPath<State>, model: Model) async {
        switch keyPath {
            case \.name:
                print("changed name")
            default:
                break
        }
    }
}

struct ItemView: ComponentView {

    @ObservedObject var model: ViewModel<ItemComponent>

    func presentation(for route: ItemComponent.Route) -> Presentation {
        switch route {
            case .detail:
                return .push
        }
    }

    func routeView(_ route: ItemComponent.Route) -> some View {
        switch route {
            case .detail(let state):
                ItemDetailView(model: model.scope(state: state, output: ItemComponent.Input.detail))
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
                model.inputButton(.updateDetail, "Update")
            }
            ItemDetailView(model: model.scope(statePath: \.detail, output: ItemComponent.Input.detail))
                .fixedSize()
            TextField("Field", text: model.binding(\.text))
                .textFieldStyle(.roundedBorder)

            model.inputButton(.calculate, "Calculate")
            model.inputButton(.openDetail, "Item")
            model.inputButton(.pushItem, "Push Item")
            Spacer()
        }
        .padding()
        .sheet(item: model.binding(\.presentDetail)) { state in
            NavigationView {
                ItemDetailView(model: model.scope(statePath: \.presentDetail, value: state, output: ItemComponent.Input.detail))
            }
        }
        .navigationBarTitleDisplayMode(.large)
        .navigationTitle(Text("Item"))
    }
}

struct ItemDetailComponent: ComponentModel {

    struct State: Identifiable, Equatable {
        var id: String
        var name: String
    }

    enum Input {
        case close
        case updateName
    }

    enum Output: Equatable {
        case finished(String)
    }

    func appear(model: Model) async {

    }

    func handleBinding(keyPath: PartialKeyPath<State>, model: Model) async {

    }

    func handle(input: Input, model: Model) async {
        switch input {
            case .close:
                model.output(.finished(model.name))
            case .updateName:
                model.name = Int.random(in: 0...100).description
        }
    }
}

struct ItemDetailView: ComponentView {

    @ObservedObject var model: ViewModel<ItemDetailComponent>

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

//struct ItemPreviewSimple: PreviewProvider {
//
//    static var previews: some View {
//        ItemView(model: State(state: .init(name: "start", data: .empty)))
////        ItemView(model: State(state: .constant(.init(name: "start", data: .empty))))
//    }
//}

struct ItemPreview: PreviewProvider, ComponentFeature {
    typealias Model = ItemComponent

    static func createView(model: ViewModel<ItemComponent>) -> some View {
        ItemView(model: model)
    }

    static var states: [ComponentState] {
        ComponentState {
            State(name: "start", data: .loading)
        }

        ComponentState("Loaded") {
            State(name: "Loaded", data: .content(2))
        }
    }

    static var tests: [ComponentTest] {
        ComponentTest("Happy New style", State(name: "john", data: .loading)) {
            Step.input(.updateDetail)
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
