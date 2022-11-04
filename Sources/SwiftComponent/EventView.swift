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
    let events: [ComponentEvent]
    let showMutations: Bool
    @State var showEvent: UUID?
    @State var showMutation: UUID?

    var body: some View {
        ForEach(events) { event in
            if showMutations, let mutations = event.mutations, !mutations.isEmpty {
                mutationsList(mutations.reversed())
            }
            NavigationLink(tag: event.id, selection: $showEvent, destination: {
                EventView(event: event)
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

    func mutationsList(_ mutations: [Mutation]) -> some View {
        ForEach(mutations) { mutation in
            NavigationLink(tag: mutation.id, selection: $showMutation, destination: {
                SwiftView(value: .constant(mutation.value), config: Config(editing: false))
            }) {
                HStack {
                    Text("🟡")
                        .font(.footnote)
                        .hidden()
//                    Text("Mutate State").bold() + Text(": \(mutation.property)")
                    Text("\(mutation.property): \(mutation.valueType)")
                    //                    Text(mutation.property + ": ") + Text(mutation.valueType).bold()
                    Spacer()
                    Text(dumpLine(mutation.value))
                        .lineLimit(1)
                }
                .font(.caption)
//                .padding(.leading, 25)
            }
        }
    }
}


struct EventView: View {

    let event: ComponentEvent
    @State var showValue = false
    @State var showMutation: UUID?

    var body: some View {
        Form {
            if let path = event.componentPath.parent {
                line("Path") {
                    Text(path.string)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            line("Component") {
                Text(event.componentName)
            }
            line("Started") {
                Text(event.start.formatted())
            }
            line("Duration") {
                Text(event.duration)
            }
            line("Location") {
                Text(verbatim: "\(event.sourceLocation.fileID)#\(event.sourceLocation.line.formatted())")
                    .lineLimit(1)
                    .truncationMode(.head)
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
            if let mutations = event.mutations, !mutations.isEmpty {
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

extension ComponentEvent {

    var duration: String {
        let seconds = end.timeIntervalSince1970 - start.timeIntervalSince1970
        if seconds < 2 {
            return Int(seconds*1000).formatted(.number) + " ms"
        } else {
            return (start ..< end).formatted(.components(style: .abbreviated))
        }
    }
}

extension EventType {

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
            case .action(let action):
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

    public var value: Any {
        switch self {
            case .action(let action):
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

let previewEvents: [ComponentEvent] = [
        ComponentEvent(
            type: .viewTask,
            componentPath: .init([ExampleComponent.self]),
            start: Date().addingTimeInterval(-1.05),
            end: Date(),
            mutations: [
                Mutation(keyPath: \ExampleComponent.State.name, value: "new1"),
                Mutation(keyPath: \ExampleComponent.State.name, value: "new2"),
            ],
            sourceLocation: .capture()
        ),

        ComponentEvent(
            type: .action(ExampleComponent.Action.tap(2)),
            componentPath: .init([ExampleComponent.self, ExampleSubComponent.self]),
            start: Date(),
            end: Date(),
            mutations: [
                Mutation(keyPath: \ExampleComponent.State.name, value: "new1"),
                Mutation(keyPath: \ExampleComponent.State.name, value: "new2"),
            ],
            sourceLocation: .capture()
        ),

        ComponentEvent(
            type: .binding(Mutation(keyPath: \ExampleComponent.State.name, value: "Hello")),
            componentPath: .init(ExampleComponent.self),
            start: Date(),
            end: Date(),
            mutations: [Mutation(keyPath: \ExampleComponent.State.name, value: "Hello")],
            sourceLocation: .capture()
        ),

        ComponentEvent(
            type: .task(TaskResult.init(name: "get item", result: .success(()))),
            componentPath: .init(ExampleComponent.self),
            start: Date().addingTimeInterval(-2.3),
            end: Date(),
            mutations: [],
            sourceLocation: .capture()
        ),

        ComponentEvent(
            type: .output(ExampleComponent.Output.finished),
            componentPath: .init(ExampleComponent.self),
            start: Date(),
            end: Date(),
            mutations: [],
            sourceLocation: .capture()
        ),
    ]

struct EventView_Previews: PreviewProvider {
    static var previews: some View {
        viewModelEvents = previewEvents
        return Group {
            NavigationView {
                EventView(event: previewEvents[1])
            }
            ExampleView(model: .init(state: .init(name: "Hello")))
                .debugView()
        }

    }
}
