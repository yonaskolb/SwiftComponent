import Foundation
import SwiftUI
import SwiftGUI

struct ComponentEventList: View {

    let events: [Event]
    let allEvents: [Event]
    var depth: Int = 0
    var indent = true
    @State var showEvent: UUID?
    @State var showMutation: UUID?

    func eventDepth(_ event: Event) -> Int {
        guard indent else { return 0 }
        return max(0, event.depth - depth)
    }

    var body: some View {
        ForEach(events) { event in
            NavigationLink(tag: event.id, selection: $showEvent, destination: {
                ComponentEventView(event: event, allEvents: allEvents)
            }) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        //                    if eventDepth(event) > 0 {
                        //                        Image(systemName: "arrow.turn.down.right")
                        //                            .opacity(0.3)
                        //                            .font(.system(size: 14))
                        //                            .padding(.top, 14)
                        //                    }
                        HStack(spacing: 6) {
                            Circle()
                                .fill(event.type.color)
                                .frame(width: 12)
                            Text(event.type.title)
                                .bold()
                        }
                        Spacer()
                        Text(event.type.details)
                            .font(.footnote)
                    }
                    .font(.footnote)
                    .padding(.top, 6)
                    Text(event.path.string)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.leading, 18)
                }
                .padding(.leading, 8*Double(max(0, eventDepth(event)))) // inset children
            }
        }
    }
}

struct ComponentEventView: View {

    let event: Event
    var allEvents: [Event]
    var childEvents: [Event] {
        allEvents
            .filter { $0.start > event.start && $0.end < event.end }
            .sorted { $0.start < $1.start }
    }
    var parentEvents: [Event] {
        allEvents
            .filter { $0.start < event.start && $0.end > event.end }
            .sorted { $0.start < $1.start }
    }
    @State var showValue = false
    @State var showMutation: UUID?

    var body: some View {
        Form {
            if !event.type.detailsTitle.isEmpty || !event.type.details.isEmpty || !event.type.valueTitle.isEmpty {
                Section {
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
                }
            }

            Section {
                if let path = event.path.parent {
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
                    Text(event.formattedDuration)
                }
                line("Location") {
                    Text(verbatim: "\(event.source.file)#\(event.source.line.formatted())")
                        .lineLimit(1)
                        .truncationMode(.head)
                }
//                line("Depth") {
//                    Text(event.depth.formatted())
//                }
            }
            if !parentEvents.isEmpty {
                Section("Parents") {
                    ComponentEventList(events: parentEvents, allEvents: allEvents, depth: 0)
                }
            }
            if !childEvents.isEmpty {
                Section("Children") {
                    ComponentEventList(events: childEvents, allEvents: allEvents, depth: event.depth + 1)
                }
            }
            switch event.type {
                case .mutation(let mutation), .binding(let mutation):
                    if let diff = mutation.stateDiff {
                        Section("Mutation") {
                            diff.diffText(textColor: .secondary)
                        }
                    }
                default:
                    EmptyView()
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

let previewEvents: [Event] = [
        Event(
            type: .view(.appear(first: true)),
            storeID: UUID(),
            componentPath: .init([ExampleModel.self]),
            start: Date().addingTimeInterval(-1.05),
            end: Date(),
            mutations: [
                Mutation(keyPath: \ExampleModel.State.name, value: "new1", oldState: ExampleModel.State(name: "old1")),
                Mutation(keyPath: \ExampleModel.State.name, value: "new2", oldState: ExampleModel.State(name: "old2")),
            ],
            depth: 0,
            source: .capture()
        ),

        Event(
            type: .action(ExampleModel.Action.tap(2)),
            storeID: UUID(),
            componentPath: .init([ExampleModel.self, ExampleChildModel.self]),
            start: Date(),
            end: Date(),
            mutations: [
                Mutation(keyPath: \ExampleModel.State.name, value: "new1", oldState: ExampleModel.State(name: "old1")),
                Mutation(keyPath: \ExampleModel.State.name, value: "new2", oldState: ExampleModel.State(name: "old2")),
            ],
            depth: 0,
            source: .capture()
        ),

        Event(
            type: .binding(Mutation(keyPath: \ExampleModel.State.name, value: "Hello", oldState: ExampleModel.State(name: "old1"))),
            storeID: UUID(),
            componentPath: .init(ExampleModel.self),
            start: Date(),
            end: Date(),
            mutations: [Mutation(keyPath: \ExampleModel.State.name, value: "Hello", oldState: ExampleModel.State(name: "old1"))],
            depth: 1,
            source: .capture()
        ),

        Event(
            type: .mutation(Mutation(keyPath: \ExampleModel.State.name, value: "Hello", oldState: ExampleModel.State(name: "old1"))),
            storeID: UUID(),
            componentPath: .init(ExampleModel.self),
            start: Date(),
            end: Date(),
            mutations: [Mutation(keyPath: \ExampleModel.State.name, value: "Hello", oldState: ExampleModel.State(name: "old1"))],
            depth: 2,
            source: .capture()
        ),

        Event(
            type: .task(TaskResult.init(name: "get item", result: .success(()))),
            storeID: UUID(),
            componentPath: .init(ExampleModel.self),
            start: Date().addingTimeInterval(-2.3),
            end: Date(),
            mutations: [],
            depth: 0,
            source: .capture()
        ),

        Event(
            type: .output(ExampleModel.Output.finished),
            storeID: UUID(),
            componentPath: .init(ExampleModel.self),
            start: Date(),
            end: Date(),
            mutations: [],
            depth: 2,
            source: .capture()
        ),
    ]

struct EventView_Previews: PreviewProvider {
    static var previews: some View {
        EventStore.shared.events = previewEvents
        return Group {
            NavigationView {
                ComponentEventView(event: previewEvents[1], allEvents: previewEvents)
            }
            .navigationViewStyle(.stack)
            ExampleView(model: .init(state: .init(name: "Hello")))
                .debugSheet()
                .navigationViewStyle(.stack)
        }

    }
}
