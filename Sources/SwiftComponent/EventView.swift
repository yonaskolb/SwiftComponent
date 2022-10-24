//
//  File.swift
//  
//
//  Created by Yonas Kolb on 24/10/2022.
//

import Foundation
import SwiftUI
import SwiftGUI

struct ComponentEventList<ComponentType: Component>: View {

    let viewModel: ViewModel<ComponentType>
    let events: [AnyEvent]
    let showMutations: Bool
    @State var showEvent: UUID?
    @State var showMutation: UUID?

    var body: some View {
        ForEach(events) { event in
            if showMutations, let mutations = event.type.mutations, !mutations.isEmpty {
                mutationsList(mutations.reversed())
            }
            NavigationLink(tag: event.id, selection: $showEvent, destination: {
                EventView(viewModel: viewModel, event: event)
            }) {
                HStack {
                    Text("\(event.type.emoji)")
                        .font(.footnote)
                        .padding(.top, 12)
                    //                                Circle()
                    //                                    .fill(event.type.color)
                    //                                    .frame(width: 12)
                    //                                    .padding(.top, 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.componentPath.string)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(event.type.title)
                            .bold()
                    }
                    .font(.footnote)
                    Spacer()
                    Text(event.type.details)
                        .font(.footnote)
                }
            }
        }
    }

    func mutationsList(_ mutations: [AnyMutation]) -> some View {
        ForEach(mutations) { mutation in
            NavigationLink(tag: mutation.id, selection: $showMutation, destination: {
                SwiftView(value: .constant(mutation.value), config: Config(editing: false))
            }) {
                HStack {
                    Text("🟡")
                        .font(.footnote)
                    Text("State").bold() + Text(".\(mutation.property)")
                    //                    Text(mutation.property + ": ") + Text(mutation.valueType).bold()
                    Spacer()
                    Text(dumpLine(mutation.value))
                        .lineLimit(1)
                }
                .font(.footnote)
                //                .padding(.leading, 25)
            }
        }
    }
}


struct EventView<ComponentType: Component>: View {

    let viewModel: ViewModel<ComponentType>
    let event: AnyEvent
    @State var showValue = false
    @State var showMutation: UUID?

    var body: some View {
        Text("")
        Form {
            if viewModel.path != event.componentPath {
                line("Path") {
                    Text(event.componentPath.relative(to: viewModel.path).string)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            line("Component") {
                Text(event.componentName)
            }
            if !event.type.detailsTitle.isEmpty || !event.type.details.isEmpty {
                line(event.type.detailsTitle) {
                    Text(event.type.details)
                }
            }
            if !event.type.valueTitle.isEmpty {
                NavigationLink(isActive: $showValue) {
                    SwiftView(value: .constant(event.type.value), config: Config(editing: false))
                } label: {
                    line(event.type.valueTitle) {
                        Text(dumpLine(event.type.value))
                            .lineLimit(1)
                    }
                }
            }
            line("Time") {
                Text(event.date.formatted())
            }
            line("Location") {
                Text(verbatim: "\(event.sourceLocation.fileID)#\(event.sourceLocation.line.formatted())")
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            if let mutations = event.type.mutations, !mutations.isEmpty {
                Section(header: Text("State Mutations")) {
                    ForEach(mutations) { mutation in
                        NavigationLink(tag: mutation.id, selection: $showMutation, destination: {
                            SwiftView(value: .constant(mutation.value), config: Config(editing: false))
                        }) {
                            HStack {
                                Text(mutation.property + ": ") + Text(mutation.valueType).bold()
                                Spacer()
                                Text(dumpLine(mutation.value))
                            }
                            .lineLimit(1)
                        }

                    }
                }
            }
        }
        .navigationTitle(Text(event.type.title))
        .navigationBarTitleDisplayMode(.inline)
    }

    func line<Content: View>(_ name: String, content: () -> Content) -> some View {
        HStack {
            Text(name)
                .bold()
            Spacer()
            content()
        }
    }
}

extension AnyEvent.EventType {

    var title: String { type.title }
    var color: Color {
        switch self {
            case .task(let result):
                switch result.result {
                    case .success: return .green
                    case .failure: return .red
                }
            default: return type.color
        }
    }
    var emoji: String {
        switch self {
            case .task(let result):
                switch result.result {
                    case .success: return "🟢"
                    case .failure: return "🔴"
                }
            default:
                return type.emoji
        }
    }
    var detailsTitle: String {
        switch self {
            case .action:
                return "Action Name"
            case .binding:
                return "Property"
            case .output:
                return "Output Name"
            case .viewTask:
                return ""
            case .task:
                return "Name"
        }
    }

    var valueTitle: String {
        switch self {
            case .action:
                return "Action"
            case .binding:
                return "Value"
            case .output:
                return "Output"
            case .viewTask:
                return ""
            case .task(let result):
                switch result.result {
                    case .success: return "Success"
                    case .failure: return "Failure"
                }
        }
    }

    public var details: String {
        switch self {
            case .action(let action, _):
                return getEnumCase(action).name
            case .binding(let mutation):
                return mutation.property
            case .output(let event):
                return getEnumCase(event).name
            case .viewTask:
                return ""
            case .task(let result):
                return result.name
        }
    }

    var mutations: [AnyMutation]? {
        switch self {
            case .action(_, let mutations): return mutations
            case .binding(let mutation): return [mutation]
            case .viewTask(let mutations): return mutations
            case .task: return nil
            case .output: return nil
        }
    }

    public var value: Any {
        switch self {
            case .action(let action, _):
                return action
            case .binding(let mutation):
                return mutation.value
            case .output(let output):
                return output
            case .viewTask:
                return ""
            case .task(let result):
                switch result.result {
                    case .success(let value): return value
                    case .failure(let error): return error
                }
        }
    }
}

let previewEvents: [AnyEvent] = [
    AnyEvent(Event<ExampleComponent>(
        .viewTask([
            .init(keyPath: \.name, value: "new1"),
            .init(keyPath: \.name, value: "new2"),
        ]),
        componentPath: .init([ExampleComponent.self]),
        sourceLocation: .capture()
    )),

    AnyEvent(Event<ExampleComponent>(
        .action(.tap(2), [
            .init(keyPath: \.name, value: "new1"),
            .init(keyPath: \.name, value: "new2"),
        ]),
        componentPath: .init([ExampleComponent.self, ExampleSubComponent.self]),
        sourceLocation: .capture()
    )),

    AnyEvent(Event<ExampleComponent>(
        .binding(Mutation(keyPath: \.name, value: "Hello")),
        componentPath: .init(ExampleComponent.self),
        sourceLocation: .capture()
    )),

    AnyEvent(Event<ExampleComponent>(
        .task(TaskResult.init(name: "get item", result: .success(()), start: Date().addingTimeInterval(-2.3), end: Date())),
        componentPath: .init(ExampleComponent.self),
        sourceLocation: .capture()
    )),

    AnyEvent(Event<ExampleComponent>(
        .output(.finished),
        componentPath: .init(ExampleComponent.self),
        sourceLocation: .capture()
    )),
]

struct EventView_Previews: PreviewProvider {
    static var previews: some View {
        viewModelEvents = previewEvents
        return Group {
            NavigationView {
                EventView(viewModel: ViewModel<ExampleComponent>.init(state: .init(name: "Hello")), event: previewEvents[0])
            }
            ExampleView(model: .init(state: .init(name: "Hello")))
                .debugView()
        }

    }
}
