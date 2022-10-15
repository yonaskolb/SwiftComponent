//
//  File.swift
//  
//
//  Created by Yonas Kolb on 2/10/2022.
//

import Foundation
import SwiftUI

@dynamicMemberLookup
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

    public var events: [Event<C>] = []

    public init(state: C.State) {
        self.state = state
        self.handler = ActionHandler(store: self)
    }

    fileprivate func event(_ eventType: Event<C>.EventType) {
        self.events.append(.init(eventType))
    }

    public func send(_ action: C.Action) {
        event(.action(action))
        Task {
            print("Action \(action)")
            await C.handle(action: action, handler)
        }
    }

    public func binding<Value>(_ keyPath: WritableKeyPath<C.State, Value>) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: {
                self.event(.binding(keyPath, $0))
                self.state[keyPath: keyPath] = $0
            }
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

    public subscript<Value>(dynamicMember keyPath: KeyPath<C.State, Value>) -> Value {
      self.state[keyPath: keyPath]
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
