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
        var jobs: JobsComponent.State?
        var jobsEmbed: JobsComponent.State = .init(id: "1")
    }

    enum Route {
        case jobs
    }

    enum Action {
        case calculate
        case openItem
        case pushItem
        case jobs(JobsComponent.Output)
    }

    func task(handler: ActionHandler<Self>) async {
        await handler.loadResource(\.data) {
            try await Task.sleep(nanoseconds: 1_000_000_000 * 1)
            return Int.random(in: 0...100)
        }
    }

    func handle(action: Action, _ handler: ActionHandler<Self>) async {
        switch action {
            case .calculate:
                try? await Task.sleep(nanoseconds: 1_000_000_000 * 1)
                handler.mutate(\.name, value: UUID().uuidString)

            case .openItem:
                handler.present(.jobs, as: .sheet, inNav: true, using: JobsComponent.self) {
                    JobsComponent.State(id: "2")
                }
                handler.mutate(\.jobs, value: .init(id: handler.state.name))
            case .pushItem:
                handler.present(.jobs, as: .push, inNav: false, using: JobsComponent.self) {
                    JobsComponent.State(id: "3")
                }
            case .jobs(.didThing):
                break
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
            .frame(height: 30)
            JobsView(store: store.scope(state: \.jobsEmbed, event: ItemComponent.Action.jobs))
            TextField("Field", text: store.binding(\.text))
                .textFieldStyle(.roundedBorder)

            store.button(.calculate) {
                Text("Calculate")
            }

            Button(action: { store.send(.openItem) }) {
                Text("Item")
            }

            Button(action: { store.send(.pushItem) }) {
                Text("Push Item")
            }
        }
        .sheet(item: store.binding(\.jobs)) { jobs in
            JobsView(store: store.scope(state: \.jobs, value: jobs, event: ItemComponent.Action.jobs))
        }
        .padding(20)
    }
}

struct JobsComponent: Component {


    struct State: Identifiable, Equatable {
        var id: String
    }

    enum Action { case close }
    enum Output { case didThing }

    func task(handler: ActionHandler<JobsComponent>) async {

    }

    func handleBinding(keyPath: PartialKeyPath<State>) async {

    }

    func handle(action: Action, _ handler: ActionHandler<JobsComponent>) async {
        switch action {
            case .close:
                handler.output(.didThing)
        }
    }
}

struct JobsView: ComponentView {

    var store: Store<JobsComponent>

    var view: some View {
        Text("Jobs \(store.state.id)")
            .navigationBarTitle(Text("Item"))
            .toolbar {
                Button(action: { store.send(.close) }) {
                    Text("Close")
                }
            }
    }
}

struct DemoPreview: PreviewProvider {

    static var previews: some View {
        NavigationView {
            ItemView(store: .init(state: .init(name: "start", data: .empty)))
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
