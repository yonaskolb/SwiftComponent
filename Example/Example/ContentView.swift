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
    }

    enum Route {
        case jobs
    }

    enum Action {
        case calculate
        case openItem
        case pushItem
    }

    func task(handler: ActionHandler<Self>) async {

    }

    func handle(action: Action, _ handler: ActionHandler<Self>) async {
        switch action {
            case .calculate:
                try? await Task.sleep(nanoseconds: 1_000_000_000 * 1)
                handler.mutate(\.name, value: UUID().uuidString)
                await handler.loadResource(\.data) {
                    try await Task.sleep(nanoseconds: 1_000_000_000 * 1)
                    return Int.random(in: 0...100)
                }
            case .openItem:
                handler.present(.jobs, as: .sheet, inNav: true, using: JobsComponent.self) {
                    JobsComponent.State(id: "2")
                }
            case .pushItem:
                handler.present(.jobs, as: .push, inNav: false, using: JobsComponent.self) {
                    JobsComponent.State(id: "3")
                }
        }
    }

    func handleBinding(keyPath: PartialKeyPath<State>) {
        switch keyPath {
            case \.name:
                print("changed name")
            default:
                break
        }
    }
}

struct ItemView: ComponentView {

    @ObservedObject var store: Store<ItemComponent>

    var view: some View {
        VStack {
            Text(store.state.name)
            if let route = store.route {
                Text("\(String(describing: route.mode)): \(String(describing: route.route))")
            }
            ResourceView(store.state.data) { state in
                Text(state.description)
            }
            TextField("Field", text: store.binding(\.text))
                .textFieldStyle(.roundedBorder)
            Button(action: { store.send(.calculate) }) {
                Text("Calculate")
            }

            Button(action: { store.send(.openItem) }) {
                Text("Item")
            }

            Button(action: { store.send(.pushItem) }) {
                Text("Push Item")
            }
        }
        .padding(20)
    }
}

struct JobsComponent: Component {


    struct State {
        var id: String
    }

    enum Action { case one }

    func task(handler: ActionHandler<JobsComponent>) async {

    }

    func handleBinding(keyPath: PartialKeyPath<State>) async {

    }

    func handle(action: Action, _ handler: ActionHandler<JobsComponent>) async {

    }
}

struct JobsView: ComponentView {

    var store: Store<JobsComponent>

    var view: some View {
        Text("Jobs \(store.state.id)")
            .navigationBarTitle(Text("Item"))
            .toolbar {
                Button(action: { store.dismiss() }) {
                    Text("Close")
                }
            }
    }
}

struct DemoPreview: PreviewProvider {

    static var previews: some View {
        NavigationView {
            ItemView(store: .init(state: .init(name: "start", data: .empty), component: ItemComponent()))
        }
    }

    static var tests: [Test<ItemComponent>] {
        return [
            Test("Happy", .init(name: "john", data: .empty), steps: [
                .action(.openItem),
            ])
        ]
    }
}
