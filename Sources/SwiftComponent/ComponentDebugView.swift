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
