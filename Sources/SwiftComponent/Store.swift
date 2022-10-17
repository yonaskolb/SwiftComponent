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

    public convenience init(state: C.State, output: @escaping (C.Output) -> Void) {
        self.init(state: state)
        listen { event in
            switch event.event {
                case .output(let event):
                    output(event)
                default: break
            }
        }
    }

    func listen(_ event: @escaping (Event<C>) -> Void) {
        listeners.append(event)
    }

    public func output(output: @escaping (C.Output) -> Void) -> Self {
        listen { event in
            switch event.event {
                case .output(let event):
                    output(event)
                default: break
            }
        }
        return self
    }

    fileprivate func event(_ eventType: Event<C>.EventType, file: StaticString, line: UInt) {
        let event = Event(eventType, file: file, line: line)
        self.events.append(event)
        print("\(C.self) \(event.event.title): \(event.event.details)")
        for listener in listeners {
            listener(event)
        }
    }

    public func send(_ action: C.Action, animation: Animation? = nil, file: StaticString = #file, line: UInt = #line) {
        event(.action(action), file: file, line: line)
        if let animation = animation {
            withAnimation(animation) {
                handleAction(action)
            }
        } else {
            handleAction(action)
        }
    }

    func handleAction(_ action: C.Action) {
        Task {
            await component.handle(action: action, handler)
        }
    }

    public func binding<Value>(_ keyPath: WritableKeyPath<C.State, Value>, file: StaticString = #file, line: UInt = #line, onSet: ((Value) -> C.Action?)? = nil) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: {
                self.event(.binding(keyPath, $0), file: file, line: line)
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
        print("\(C.self) task")
        await component.task(handler: handler)
    }

    func output(_ event: C.Output, file: StaticString = #file, line: UInt = #line) {
        self.event(.output(event), file: file, line: line)
    }

    func mutate<Value>(_ keyPath: WritableKeyPath<C.State, Value>, value: Value, file: StaticString = #file, line: UInt = #line) {
        event(.mutation(keyPath, value), file: file, line: line)
        state[keyPath: keyPath] = value
//        print(stateDump)
    }
}

public struct Event<C: Component>: Identifiable {

    public var id = UUID()
    public var date = Date()
    public var event: EventType
    public let file: StaticString
    public let line: UInt

    public init(_ event: EventType, file: StaticString = #file, line: UInt = #line) {
        self.event = event
        self.file = file
        self.line = line
    }

    public enum EventType {
        case action(C.Action)
        case mutation(PartialKeyPath<C.State>, Any)
        case binding(PartialKeyPath<C.State>, Any)
        case output(C.Output)

        public var title: String {
            switch self {
                case .action: return "Action"
                case .mutation: return "Mutation"
                case .binding: return "Binding"
                case .output: return "Output"
            }
        }

        public var details: String {
            switch self {
                case .action(let action): return String(describing: action)
                case .mutation(let keyPath, let value): return String(describing: value)
                case .binding(let keyPath, let value): return String(describing: value)
                case .output(let event): return String(describing: event)
            }
        }
    }
}

public struct ActionHandler<C: Component> {

    let store: Store<C>

    init(store: Store<C>) {
        self.store = store
    }

    public var state: C.State { store.state }

    public func mutate<Value>(_ keyPath: WritableKeyPath<C.State, Value>, value: Value, file: StaticString = #file, line: UInt = #line) {
        store.mutate(keyPath, value: value, file: file, line: line)
    }

    public func present<PC: Component>(_ route: C.Route, as mode: PresentationMode, inNav: Bool, using component: PC.Type, create: () -> PC.State) {
        store.present(route, as: mode, inNav: inNav, using: component, create: create)
    }

    public func output(_ event: C.Output, file: StaticString = #file, line: UInt = #line) {
        store.output(event, file: file, line: line)
    }
}

extension ActionHandler {

    public func loadResource<ResourceState>(_ keyPath: WritableKeyPath<C.State, Resource<ResourceState>>, load: () async throws -> ResourceState) async {
        mutate(keyPath.appending(path: \.isLoading), value: true)
        do {
            let content = try await load()
            mutate(keyPath.appending(path: \.content), value: content)
            print("Loaded resource  \(ResourceState.self):\n\(content)")
        } catch {
            mutate(keyPath.appending(path: \.error), value: error)
            print("Failed to load resource \(ResourceState.self)")
        }
        mutate(keyPath.appending(path: \.isLoading), value: false)
    }
}

extension Store {

    func _scope<Child: Component>(state stateKeyPath: WritableKeyPath<C.State, Child.State>) -> Store<Child> where Child.State: Equatable {
        let state = self.state[keyPath: stateKeyPath]
        let store = Store<Child>(state: state)
        var settingChild = false
        var settingParent = false

        self.$state.sink { state in
            guard !settingChild else { return }
            settingParent = true
            let childState = self.state[keyPath: stateKeyPath]
            if childState != store.state {
                store.state = childState
            }
            settingParent = false
        }
        .store(in: &cancellables)

        store.$state.dropFirst().sink { state in
            guard !settingParent else { return }
            settingChild = true
            self.state[keyPath: stateKeyPath] = state
            settingChild = false
        }
        .store(in: &cancellables)

        return store
    }

    func _scope<Child: Component>(state stateKeyPath: WritableKeyPath<C.State, Child.State?>, value: Child.State) -> Store<Child> where Child.State: Equatable {
        let state = value
        let store = Store<Child>(state: state)
        var settingChild = false
        var settingParent = false

        self.$state.sink { state in
            guard !settingChild else { return }
            settingParent = true
            let childState = self.state[keyPath: stateKeyPath]
            if let childState = childState, childState != store.state {
                store.state = childState
            }
            settingParent = false
        }
        .store(in: &cancellables)

        store.$state.dropFirst().sink { state in
            guard !settingParent else { return }
            settingChild = true
            self.state[keyPath: stateKeyPath] = state
            settingChild = false
        }
        .store(in: &cancellables)

        return store
    }

    public func scope<Child: Component>(state stateKeyPath: WritableKeyPath<C.State, Child.State>, event toAction: @escaping (Child.Output) -> C.Action) -> Store<Child> where Child.State: Equatable {
        let store = _scope(state: stateKeyPath) as Store<Child>
        store.listen { event in
            switch event.event {
                case .output(let output):
                    let action = toAction(output)
                    self.send(action)
                default:
                    break
            }
        }
        return store
    }

    public func scope<Child: Component>(state stateKeyPath: WritableKeyPath<C.State, Child.State?>, value: Child.State, event toAction: @escaping (Child.Output) -> C.Action) -> Store<Child> where Child.State: Equatable {
        let store = _scope(state: stateKeyPath, value: value) as Store<Child>
        store.listen { event in
            switch event.event {
                case .output(let output):
                    let action = toAction(output)
                    self.send(action)
                default:
                    break
            }
        }
        return store
    }

    public func scope<Child: Component>(state stateKeyPath: WritableKeyPath<C.State, Child.State?>, value: Child.State) -> Store<Child> where Child.State: Equatable, Child.Output == Never {
        _scope(state: stateKeyPath, value: value)
    }

    public func scope<Child: Component>(state stateKeyPath: WritableKeyPath<C.State, Child.State>) -> Store<Child> where Child.State: Equatable, Child.Output == Never {
        _scope(state: stateKeyPath)
    }
}
