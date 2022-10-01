import SwiftUI

public protocol Component: View {

    associatedtype State
    associatedtype Action = Never
    associatedtype Route = Never
    associatedtype ComponentView : View
    @ViewBuilder @MainActor var view: Self.ComponentView { get }
    func task() async
    var store: Store<Self> { get }
    init(store: Store<Self>)
    static func handleBinding(keyPath: KeyPath<State, Action>) async
    static func handle(action: Action, _ handler: ActionHandler<Self>) async

}

public class Store<C: Component>: ObservableObject {

    @Published public var state: C.State
    @Published public var route: PresentedRoute<C.Route>?
    @Published var viewModes: [ComponentViewMode] = [.view]
    var handler: ActionHandler<C>!

    var stateDump: String {
        var string = ""
        dump(state, to: &string)
        return string
    }

    public init(state: C.State) {
        self.state = state
        self.handler = ActionHandler(store: self)
    }

    public func send(_ action: C.Action) {
        Task {
            await C.handle(action: action, handler)
        }
    }

    public func binding<Value>(_ keyPath: WritableKeyPath<C.State, Value>) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { self.state[keyPath: keyPath] = $0}
        )
    }

    fileprivate func present<PC: Component>(_ route: C.Route, as mode: PresentationMode, inNav: Bool, using component: PC.Type, create: () -> PC.State) {
        let state = create()
        let component: PC = PC(store: Store<PC>(state: state))
        self.route = PresentedRoute(route: route, mode: mode, inNav: inNav, component: AnyView(component))
    }

    public func dismiss() {
        self.route = nil
    }
}

public extension Component {

    @MainActor
    var body: some View {
        VStack {
            ForEach(store.viewModes) { viewMode in
                switch viewMode {
                    case .view: view
                    case .data: Text(store.stateDump)
                    case .actions: Text(String(describing: Action.self))
                }
            }
            .frame(maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            withAnimation {
                switch store.viewModes {
                    case [.view]:
                        store.viewModes = [.view, .data]
                    case [.view, .data]:
                        store.viewModes = [.data]
                    case [.data]:
                        store.viewModes = [.data, .view]
                    case [.data, .view]:
                        store.viewModes = [.view]
                    default:
                        break
                }
            }
        }
        .task { await task() }
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

public class ActionHandler<C: Component> {

    public let store: Store<C>

    init(store: Store<C>) {
        self.store = store
    }

    public func mutate<Value>(_ keyPath: WritableKeyPath<C.State, Value>, value: Value, function: StaticString = #file, line: UInt = #line) {
        store.state[keyPath: keyPath] = value
        print("Mutating \(C.self): \(keyPath) = \(value)")
    }

    public func loadResource<ResourceState>(_ keyPath: WritableKeyPath<C.State, Resource<ResourceState>>, load: () async throws -> ResourceState) async {
        do {
            store.state[keyPath: keyPath].isLoading = true
            let content = try await load()
            store.state[keyPath: keyPath].isLoading = false
            store.state[keyPath: keyPath].content = content
            print("Loaded resource  \(ResourceState.self):\n\(content)")
        } catch {
            store.state[keyPath: keyPath].isLoading = false
            store.state[keyPath: keyPath].error = error
            print("Failed to load resource \(ResourceState.self)")
        }
    }

    public func present<PC: Component>(_ route: C.Route, as mode: PresentationMode, inNav: Bool, using component: PC.Type, create: () -> PC.State) {
        store.present(route, as: mode, inNav: inNav, using: component, create: create)
    }
}
