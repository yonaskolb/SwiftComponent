//
//  ContentView.swift
//  Example
//
//  Created by Yonas Kolb on 1/10/2022.
//

import SwiftUI
import SwiftComponent

struct ItemComponent: Component {

    struct State {
        var name: String
        var text: String = "text"
        var data: Resource<Int>
        var presentDetail: ItemDetailComponent.State?
        var detail: ItemDetailComponent.State = .init(id: "0", name: "0")
    }

    enum Route {
        case detail
    }

    enum Action {
        case calculate
        case openDetail
        case pushItem
        case detail(ItemDetailComponent.Output)
        case updateDetail
    }

    func task(model: Model) async {
        await model.loadResource(\.data) {
            try await Task.sleep(nanoseconds: 1_000_000_000 * 1)
            return Int.random(in: 0...100)
        }
    }

    func handle(action: Action, model: Model) async {
        switch action {
            case .calculate:
                try? await Task.sleep(nanoseconds: 1_000_000_000 * 1)
                model.name = String(UUID().uuidString.prefix(6))
            case .openDetail:
                model.present(.detail, as: .sheet, inNav: true, using: ItemDetailComponent.self) {
                    model.state.detail
                }
                model.presentDetail = model.detail
            case .pushItem:
                model.present(.detail, as: .push, inNav: false, using: ItemDetailComponent.self) {
                    ItemDetailComponent.State(id: model.state.data.content?.description ?? "1", name: model.state.name)
                }
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

    var view: some View {
        NavigationView {
            VStack {
                Text(model.state.name)
                if let route = model.route {
                    Text("\(String(describing: route.mode)): \(String(describing: route.route))")
                }
                ResourceView(model.state.data) { state in
                    Text(state.description)
                }
                .frame(height: 30)
                HStack {
                    Text("Detail name: \(model.state.detail.name)")
                    Button(action: { model.send(.updateDetail)}) {
                        Text("Update")
                    }
                }
                ItemDetailView(model: model.scope(state: \.detail, event: ItemComponent.Action.detail))
                    .fixedSize()
                TextField("Field", text: model.binding(\.text))
                    .textFieldStyle(.roundedBorder)

                model.actionButton(.calculate, "Calculate")
                model.actionButton(.openDetail, "Item")
                model.actionButton(.pushItem, "Push Item")
                Spacer()
            }
            .padding()
            .sheet(item: model.binding(\.presentDetail)) { state in
                NavigationView {
                    ItemDetailView(model: model.scope(state: \.presentDetail, value: state, event: ItemComponent.Action.detail))
                }
            }
            .navigationBarTitleDisplayMode(.large)
            .navigationTitle(Text("Item"))
        }
    }
}

struct ItemDetailComponent: Component {

    struct State: Identifiable, Equatable {
        var id: String
        var name: String
    }

    enum Action {
        case close
        case updateName
    }

    enum Output {
        case finished(String)
    }

    func task(model: Model) async {

    }

    func handleBinding(keyPath: PartialKeyPath<State>, model: Model) async {

    }

    func handle(action: Action, model: Model) async {
        switch action {
            case .close:
                model.output(.finished(model.state.name))
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
//        ItemView(model: .init(state: .init(name: "start", data: .empty)))
////        ItemView(model: .init(state: .constant(.init(name: "start", data: .empty))))
//    }
//}

struct ItemPreview: PreviewProvider, ComponentPreview {
    typealias ComponentType = ItemComponent
    typealias ComponentViewType = ItemView

    static var states: [ComponentState] {
        ComponentState {
            .init(name: "start", data: .empty)
        }

        ComponentState("Loaded") {
            .init(name: "Loaded", data: .content(2))
        }
    }

    static var tests: [ComponentTest] {
        ComponentTest("Happy", .init(name: "john", data: .empty), steps: [
            .action(.updateDetail),
            .setBinding(\.text, "yeah"),
            .validateState { state in
                state.text == "yeah"
            },
            .expectState { state in
                state.name = "yeah"
            }
        ])
    }
}
