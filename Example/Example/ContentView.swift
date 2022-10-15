//
//  ContentView.swift
//  Example
//
//  Created by Yonas Kolb on 1/10/2022.
//

import SwiftUI
import SwiftComponent

struct ItemView: Component {

    @ObservedObject var store: Store<Self>

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

    func task() async  {

    }

    static func handle(action: Action, _ handler: ActionHandler<Self>) async {
        switch action {
            case .calculate:
                try? await Task.sleep(nanoseconds: 1_000_000_000 * 1)
                handler.mutate(\.name, value: UUID().uuidString)
                await handler.loadResource(\.data) {
                    try await Task.sleep(nanoseconds: 1_000_000_000 * 1)
                    return Int.random(in: 0...100)
                }
            case .openItem:
                handler.present(.jobs, as: .sheet, inNav: true, using: Jobs.self) {
                    Jobs.State(id: "2")
                }
            case .pushItem:
                handler.present(.jobs, as: .push, inNav: false, using: Jobs.self) {
                    Jobs.State(id: "3")
                }
        }
    }

    static func handleBinding(keyPath: PartialKeyPath<State>) {
        switch keyPath {
            case \.name:
                print("changed name")
            default:
                break
        }
    }

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

struct Jobs: Component {

    static func handleBinding(keyPath: PartialKeyPath<State>) async {

    }

    static func handle(action: Action, _ handler: ActionHandler<Jobs>) async {

    }

    struct State {
        var id: String
    }

    enum Action { case one }

    var store: Store<Self>

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
            ItemView(store: Store<ItemView>(state: ItemView.State(name: "start", data: .empty)))
        }
    }

    static var tests: [Test<ItemView>] {
        return [
            Test("Happy", .init(name: "john", data: .empty), steps: [
                .action(.openItem),
            ])
        ]
    }
}
