import SwiftUI

public protocol Component: View {

    associatedtype State
    associatedtype Action = Never
    associatedtype Route = Never
    associatedtype ComponentView : View
    @ViewBuilder @MainActor var view: Self.ComponentView { get }
    func task(handler: ActionHandler<Self>) async
    var store: Store<Self> { get }
    init(store: Store<Self>)
    static func handleBinding(keyPath: PartialKeyPath<State>) async
    static func handle(action: Action, _ handler: ActionHandler<Self>) async
}

struct EnumCase {
    let name: String
    let values: [String: Any]
}

func getEnumCase<T>(_ enumValue: T) -> EnumCase {
    let reflection = Mirror(reflecting: enumValue)
    guard reflection.displayStyle == .enum,
        let associated = reflection.children.first else {
        return EnumCase(name: "\(enumValue)", values: [:])
    }
    let valuesChildren = Mirror(reflecting: associated.value).children
    var values = [String: Any]()
    for case let item in valuesChildren where item.label != nil {
        values[item.label!] = item.value
    }
    return EnumCase(name: associated.label!, values: values)
}

public extension Component {

    @MainActor
    var body: some View {
        VStack {
            ForEach(store.viewModes) { viewMode in
                switch viewMode {
                    case .view: view
                    case .data: Text(store.stateDump)
                    case .history:
                        List {
                            ForEach(store.events) { event in
                                HStack {
                                    Text(event.event.title)
                                        .bold()
                                    Text(event.event.details)
                                    Spacer()
                                }
                            }
                        }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            withAnimation {
                switch store.viewModes {
                    case [.view]:
                        store.viewModes = [.data]
                    case [.data]:
                        store.viewModes = [.history]
                    case [.history]:
                        store.viewModes = [.view]
//                    case [.view]:
//                        store.viewModes = [.view, .data]
//                    case [.view, .data]:
//                        store.viewModes = [.data]
//                    case [.data]:
//                        store.viewModes = [.data, .view]
//                    case [.data, .view]:
//                        store.viewModes = [.view]
                    default:
                        break
                }
            }
        }
        .task { await task(handler: store.handler) }
        .background {
            NavigationLink(isActive: Binding(get: { store.route?.mode == .push }, set: { present in
                if !present {
                    store.route = nil
                }
            })) {
                routeView()
            } label: {
                EmptyView()
            }
        }
        .sheet(isPresented: Binding(get: { store.route?.mode == .sheet }, set: { present in
            if !present {
                store.route = nil
            }
        })) {
            routeView()
        }
    }


    @ViewBuilder
    func routeView() -> some View {
        if let route = store.route {
            if route.inNav {
                NavigationView { route.component }
            } else {
                route.component
            }
        } else {
            EmptyView()
        }
    }

    func task() async {

    }

    func binding<Value>(_ keyPath: WritableKeyPath<State, Value>) -> Binding<Value> {
        store.binding(keyPath)
    }

    var state: State { store.state }
}

//public extension Component where Action == Never {
//    static func handle(action: Action, _ handler: ActionHandler<Self>) async {}
//}
//
public extension Component where State == Never {
    static func handleBinding(keyPath: KeyPath<State, Action>) async { }
}
