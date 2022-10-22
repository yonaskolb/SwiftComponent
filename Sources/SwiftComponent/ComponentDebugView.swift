//
//  SwiftUIView.swift
//  
//
//  Created by Yonas Kolb on 21/10/2022.
//

import SwiftUI
import SwiftGUI
import CustomDump

struct ComponentDebugView<ComponentType: Component>: View {

    let viewModel: ViewModel<ComponentType>
    @Environment(\.dismiss) var dismiss

    @State var showStateEditor = false
    @State var showStateOutput = false
    @State var showEvents = false
    @State var eventTypes = EventSimpleType.set
    @AppStorage("showMutations") var showMutations = false
    @AppStorage("showBindings") var showBindings = true
    @AppStorage("showChildEvents") var showChildEvents = true

    var events: [AnyEvent] {
        componentEvents(for: viewModel.path, includeChildren: showChildEvents)
            .filter { eventTypes.contains($0.type.type) }
            .reversed()
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    if let parent = viewModel.path.parent {
                        HStack {
                            Text("Parent")
                                .bold()
                            Spacer()
                            Text(parent.string)
                                .lineLimit(2)
                                .truncationMode(.head)
                        }
                    }
                    NavigationLink(destination: SwiftView(value: viewModel.binding(\.self), config: Config(editing: true)), isActive: $showStateEditor) {
                        HStack {
                            Text("State")
                                .bold()
                            Spacer()
                            Text(dumpLine(viewModel.state))
                                .lineLimit(1)
                        }
                    }
                }
                Section(header: Text("Event filtering")) {
                    Toggle("Show Children", isOn: $showChildEvents)
                    Toggle("Show State Mutations", isOn: $showMutations)
                        HStack {
                            Text("Show Types")
                            Spacer()
                            ForEach(EventSimpleType.allCases, id: \.rawValue) { event in
                                Button {
                                    if eventTypes.contains(event) {
                                        eventTypes.remove(event)
                                    } else {
                                        eventTypes.insert(event)
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(event.emoji)
                                            .font(.system(size: 20))
                                            .padding(2)
                                    }
                                    .opacity(eventTypes.contains(event) ? 1 : 0.2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
                Section(header: eventsHeader) {
                    ComponentEventList(
                        viewModel: viewModel,
                        events: events,
                        showMutations: showMutations)
                }
            }
            .animation(.default, value: eventTypes)
            .animation(.default, value: showMutations)
            .animation(.default, value: showChildEvents)
            .navigationTitle(viewModel.componentName + " Component")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss ()}) {
                        Text("Close")
                    }
                }
            }
        }
    }

    var eventsHeader: some View {
        HStack {
            Text("Events")
            Spacer()
            Text(events.count.formatted())
        }
    }

    var componentHeader: some View {
        Text(viewModel.componentName)
            .bold()
            .textCase(.none)
            .font(.headline)
            .foregroundColor(.primary)
    }
}

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
                        .padding(.top, 8)
                    //                                Circle()
                    //                                    .fill(event.type.color)
                    //                                    .frame(width: 12)
                    //                                    .padding(.top, 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.componentPath.string)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        HStack {
                            Text(event.type.title)
                                .bold()
                            +
                            Text(event.type.details != "" ? ".\(event.type.details)" : "")
                        }
                        .font(.footnote)
                    }
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
    var color: Color { type.color }
    var emoji: String { type.emoji }
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
        }
    }

    var mutations: [AnyMutation]? {
        switch self {
            case .action(_, let mutations): return mutations
            case .binding(let mutation): return [mutation]
            case .viewTask(let mutations): return mutations
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
        }
    }
}

extension ComponentView {

    func debugView() -> ComponentDebugView<C> {
        ComponentDebugView(viewModel: model)
    }
}

struct ComponentDebugView_Previews: PreviewProvider {

    static let events: [AnyEvent] = [
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
            .output(.finished),
            componentPath: .init(ExampleComponent.self),
            sourceLocation: .capture()
        )),
    ]
    static func createTestEvents() {
        viewModelEvents = events
    }
    static var previews: some View {
        Self.createTestEvents()
        return Group {
            ExampleView(model: .init(state: .init(name: "Hello")))
                .debugView()
            NavigationView {
                EventView(viewModel: ViewModel<ExampleComponent>.init(state: .init(name: "Hello")), event: events[0])
            }
        }
    }
}
