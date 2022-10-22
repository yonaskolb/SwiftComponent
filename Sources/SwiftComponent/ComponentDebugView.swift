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

    var events: [AnyEvent] {
        componentEvents(for: viewModel.path, includeChildren: true)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    if let parent = viewModel.path.parent {
                        HStack {
                            Text("Parent")
                            Spacer()
                            Text(parent.string)
                                .lineLimit(2)
                                .truncationMode(.head)
                        }
                    }
                    NavigationLink("State", isActive: $showStateEditor) {
                        SwiftView(value: viewModel.binding(\.self), config: Config(editing: true))
                    }
//                    NavigationLink("State Output", isActive: $showStateOutput) {
//                        ScrollView {
//                            Text(viewModel.stateDump)
//                                .frame(maxWidth: .infinity)
//                                .padding()
//                        }
//                    }
                    NavigationLink.init(destination: ComponentEventsView(viewModel: viewModel), isActive: $showEvents) {
                        HStack {
                            Text("Events")
                            Spacer()
                            Text(events.count.formatted())
                        }
                    }
                }
            }
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

    var componentHeader: some View {
        Text(viewModel.componentName)
            .bold()
            .textCase(.none)
            .font(.headline)
            .foregroundColor(.primary)
    }
}

struct ComponentEventsView<ComponentType: Component>: View {

    let viewModel: ViewModel<ComponentType>

    @AppStorage("showMutations") var showMutations = false
    @AppStorage("showBindings") var showBindings = true
    @AppStorage("showChildEvents") var showChildEvents = true
    @State var showEvent: UUID?
    @State var showMutation: UUID?

    var events: [AnyEvent] {
        componentEvents(for: viewModel.path, includeChildren: showChildEvents)
            .filter { event in
                if showBindings {
                    return true
                }
                switch event.type {
                    case .binding: return false
                    default: return true
                }
            }
            .reversed()
    }

    var body: some View {
        Form {
            Section {
                Toggle("Show State Mutations", isOn: $showMutations.animation())
                Toggle("Show Bindings", isOn: $showBindings.animation())
                Toggle("Show Children", isOn: $showChildEvents.animation())
            }
            Section(header: eventsHeader) {
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
                .animation(.default)
            }
        }
        .navigationTitle("Events")
        .navigationBarTitleDisplayMode(.inline)
    }

    var eventsHeader: some View {
        HStack {
            Text("Events")
            Spacer()
            Text(events.count.formatted())
        }
    }

    func mutationsList(_ mutations: [AnyMutation]) -> some View {
        ForEach(mutations) { mutation in
            NavigationLink(tag: mutation.id, selection: $showMutation, destination: {
                SwiftView(value: .constant(mutation.value), config: Config(editing: false))
            }) {
                HStack {
                    Circle().fill(Color.yellow)
                        .frame(width: 12)
                    Text("State").bold() + Text(".\(mutation.property)")
                    //                    Text(mutation.property + ": ") + Text(mutation.valueType).bold()
                    Spacer()
                    Text(dump(mutation.value))
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
                        Text(dump(event.type.value))
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
                                Text(dump(mutation.value))
                                    .lineLimit(1)
                            }
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

private func dump(_ value: Any) -> String {
    var string = ""
    customDump(value, to: &string)
    return string
}

extension AnyEvent.EventType {

    public var title: String {
        switch self {
            case .action: return "Action"
            case .binding: return "Binding"
            case .output: return "Output"
            case .viewTask: return "View Task"
        }
    }

    var color: Color {
        switch self {
            case .action:
                return .blue
            case .binding:
                return .green
            case .output:
                return .purple
            case .viewTask:
                return .orange
        }
    }

    var emoji: String {
        switch self {
            case .action:
                return "🔵"
            case .binding:
                return "🟢"
            case .output:
                return "🟣"
            case .viewTask:
                return "🟠"
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
            .action(.tap(UUID()), [
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
