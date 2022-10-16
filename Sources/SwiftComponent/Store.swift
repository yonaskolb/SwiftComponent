//
//  File.swift
//  
//
//  Created by Yonas Kolb on 2/10/2022.
//

import Foundation
import SwiftUI
import Combine

@dynamicMemberLookup
public class Store<C: Component>: ObservableObject {

    @Published public var state: C.State
    @Published public var route: PresentedRoute<C.Route>?
    @Published var viewModes: [ComponentViewMode] = [.view]
    
    var handler: ActionHandler<C>!
    var component: C
    var cancellables: Set<AnyCancellable> = []

    var stateDump: String {
        var string = ""
        dump(state, to: &string)
        return string
    }

    public var events: [Event<C>] = []
    var listeners: [(Event<C>) -> Void] = []

    public init(state: C.State) {
        self.state = state
        self.component = C()
        self.handler = ActionHandler(store: self)
    }

    func listen(_ event: @escaping (Event<C>) -> Void) {
        listeners.append(event)
    }

    fileprivate func event(_ eventType: Event<C>.EventType) {
        self.events.append(.init(eventType))
    }

    public func send(_ action: C.Action) {
        event(.action(action))
        print("Action \(action)")
        handleAction(action)
    }

    func handleAction(_ action: C.Action) {
        Task {
            await component.handle(action: action, handler)
        }
    }

    public func binding<Value>(_ keyPath: WritableKeyPath<C.State, Value>, onSet: ((Value) -> C.Action?)? = nil) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: {
                self.event(.binding(keyPath, $0))
                self.state[keyPath: keyPath] = $0
                if let onSet = onSet, let action = onSet($0) {
                    self.send(action)
                }
            }
        )
    }

    fileprivate func present<PC: Component>(_ route: C.Route, as mode: PresentationMode, inNav: Bool, using component: PC.Type, create: () -> PC.State) {
        let state = create()
//        let component: PC = PC(store: Store<PC>(state: state))
//        self.route = PresentedRoute(route: route, mode: mode, inNav: inNav, component: AnyView(component))
    }

    public func dismiss() {
        self.route = nil
    }

    public subscript<Value>(dynamicMember keyPath: KeyPath<C.State, Value>) -> Value {
      self.state[keyPath: keyPath]
    }

    func task() async {
        await component.task(handler: handler)
    }
}

public struct Event<C: Component>: Identifiable {

    public var id = UUID()
    public var date = Date()
    public var event: EventType

    public init(_ event: EventType) {
        self.event = event
    }

    public enum EventType {
        case action(C.Action)
        case mutation(PartialKeyPath<C.State>, Any)
        case binding(PartialKeyPath<C.State>, Any)

        public var title: String {
            switch self {
                case .action: return "Action"
                case .mutation: return "Mutation"
                case .binding: return "Binding"
            }
        }

        public var details: String {
            switch self {
                case .action(let action): return String(describing: action)
                case .mutation(let keyPath, let value): return String(describing: value)
                case .binding(let keyPath, let value): return String(describing: value)
            }
        }
    }
}

public class ActionHandler<C: Component> {

    let store: Store<C>

    init(store: Store<C>) {
        self.store = store
    }

    public var state: C.State { store.state }

    public func mutate<Value>(_ keyPath: WritableKeyPath<C.State, Value>, value: Value, function: StaticString = #file, line: UInt = #line) {
        store.event(.mutation(keyPath, value))
        store.state[keyPath: keyPath] = value
        print("Mutating \(C.self): \(keyPath) = \(value)")
    }

    public func present<PC: Component>(_ route: C.Route, as mode: PresentationMode, inNav: Bool, using component: PC.Type, create: () -> PC.State) {
        store.present(route, as: mode, inNav: inNav, using: component, create: create)
    }
}

extension ActionHandler {

    public func loadResource<ResourceState>(_ keyPath: WritableKeyPath<C.State, Resource<ResourceState>>, load: () async throws -> ResourceState) async {
        do {
            mutate(keyPath.appending(path: \.isLoading), value: true)
            let content = try await load()
            mutate(keyPath.appending(path: \.isLoading), value: false)
            mutate(keyPath.appending(path: \.content), value: content)
            print("Loaded resource  \(ResourceState.self):\n\(content)")
        } catch {
            mutate(keyPath.appending(path: \.isLoading), value: false)
            mutate(keyPath.appending(path: \.error), value: error)
            print("Failed to load resource \(ResourceState.self)")
        }
    }
}

extension Store {

    public func scope<Child: Component>(
        state toChildState: @escaping (C.State) -> Child.State,
        action fromChildAction: @escaping (Child.Action) -> C.Action
    ) -> Store<Child> where Child.State: Equatable {

        var state = toChildState(self.state)
        let store = Store<Child>(state: state)
        store.listen { event in
            switch event.event {
                case .action(let childAction):
                    let action = fromChildAction(childAction)
                    self.handleAction(action)
                default:
                    break
            }
        }
        self.$state.sink { state in
            let childState = toChildState(state)
            if childState != store.state {
                store.state = childState
            }
        }
        .store(in: &cancellables)

        //TODO: mutations in child should mutate parent
        return store
    }
}
