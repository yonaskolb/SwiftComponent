import SwiftUI
import SwiftGUI
import CustomDump

struct ComponentDebugView<Model: ComponentModel>: View {

    let model: ViewModel<Model>
    @Environment(\.dismiss) var dismiss

    @State var showStateEditor = false
    @State var showStateOutput = false
    @State var showEvents = false
    @State var eventTypes = EventSimpleType.set
    @AppStorage("showBindings") var showBindings = true
    @AppStorage("showChildEvents") var showChildEvents = true

    var events: [Event] {
        EventStore.shared.componentEvents(for: model.store.path, includeChildren: showChildEvents)
            .filter { eventTypes.contains($0.type.type) }
            .sorted { $0.start < $1.start }
    }

    var body: some View {
        NavigationView {
            Form {
                if let parent = model.store.path.parent {
                    Section(header: Text("Parent")) {
                        Text(parent.string)
                            .lineLimit(2)
                            .truncationMode(.head)
                    }
                }

                Section(header: Text("State")) {
                    SwiftView(value: model.binding(\.self), config: Config(editing: true))
                        .showRootNavTitle(false)
                }
                Section(header: eventsHeader) {
                    Toggle("Show Children", isOn: $showChildEvents)
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
                                    Circle().fill(event.color)
                                        .frame(width: 18)
                                        .padding(2)
                                }
                                .opacity(eventTypes.contains(event) ? 1 : 0.2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                Section {
                    ComponentEventList(events: events, allEvents: EventStore.shared.events.sorted { $0.start < $1.start })
                }
            }
            .animation(.default, value: eventTypes)
            .animation(.default, value: showChildEvents)
            .navigationTitle(model.componentName + " Component")
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
        Text(model.componentName)
            .bold()
            .textCase(.none)
            .font(.headline)
            .foregroundColor(.primary)
    }
}

extension ComponentView {

    func debugView() -> ComponentDebugView<Model> {
        ComponentDebugView(model: model)
    }
}

struct ComponentDebugView_Previews: PreviewProvider {

    static var previews: some View {
        EventStore.shared.events = previewEvents
        return ExampleView(model: .init(state: .init(name: "Hello")))
            .debugView()
            .navigationViewStyle(.stack)
    }
}
