//
//  File.swift
//  
//
//  Created by Yonas Kolb on 2/10/2022.
//

import Foundation
import SwiftUI
import Combine
import CustomDump

@dynamicMemberLookup
public class ViewModel<C: Component>: ObservableObject {

    private var stateBinding: Binding<C.State>?
    private var ownedState: C.State?

    public internal(set) var state: C.State {
        get {
            ownedState ?? stateBinding!.wrappedValue
        }
        set {
            if let stateBinding = stateBinding {
                stateBinding.wrappedValue = newValue
            } else {
                ownedState = newValue
            }
            objectWillChange.send()
        }
    }

    @Published public var route: PresentedRoute<C.Route>?
    @Published var viewModes: [ComponentViewMode] = [.view]
    let id = UUID()
    
    var componentModel: ComponentModel<C>!
    var component: C
    var cancellables: Set<AnyCancellable> = []

    var stateDump: String {
        var string = ""
        customDump(state, to: &string)
        return string
    }

    public var events: [Event<C>] = []
    var listeners: [(Event<C>) -> Void] = []

    public init(state: C.State) {
        self.ownedState = state
        self.component = C()
        self.componentModel = ComponentModel(viewModel: self)
    }

    public init(state: Binding<C.State>) {
        self.stateBinding = state
        self.component = C()
        self.componentModel = ComponentModel(viewModel: self)
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
        Task { @MainActor in
            await component.handle(action: action, model: componentModel)
        }
    }

    func mutate<Value>(_ keyPath: WritableKeyPath<C.State, Value>, value: Value, file: StaticString = #file, line: UInt = #line) {
        let oldState = state
        self.event(.mutation(keyPath, value, (keyPath as KeyPath).fieldName ?? ""), file: file, line: line)
        self.state[keyPath: keyPath] = value
        print(diff(oldState, self.state) ?? "  No state changes")
    }

    public func binding<Value>(_ keyPath: WritableKeyPath<C.State, Value>, file: StaticString = #file, line: UInt = #line, onSet: ((Value) -> C.Action?)? = nil) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: {
                let oldState = self.state
                self.event(.binding(keyPath, $0, (keyPath as KeyPath).fieldName ?? ""), file: file, line: line)
                self.state[keyPath: keyPath] = $0
                print(diff(oldState, self.state) ?? "  No state changes")
                if let onSet = onSet, let action = onSet($0) {
                    self.send(action)
                }
            }
        )
    }

    fileprivate func present<PC: Component>(_ route: C.Route, as mode: PresentationMode, inNav: Bool, using component: PC.Type, create: () -> PC.State) {
        let state = create()
//        let component: PC = PC(viewModel: ViewModel<PC>(state: state))
//        self.route = PresentedRoute(route: route, mode: mode, inNav: inNav, component: AnyView(component))
    }

    public func dismiss() {
        self.route = nil
    }

    @MainActor
    func task() async {
        //print("\(C.self) task")
        await component.task(model: componentModel)
    }

    func output(_ event: C.Output, file: StaticString = #file, line: UInt = #line) {
        self.event(.output(event), file: file, line: line)
    }

    public subscript<Value>(dynamicMember keyPath: KeyPath<C.State, Value>) -> Value {
      self.state[keyPath: keyPath]
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
        case mutation(PartialKeyPath<C.State>, Any, String)
        case binding(PartialKeyPath<C.State>, Any, String)
        case output(C.Output)

        public var title: String {
            switch self {
                case .action: return "action"
                case .mutation: return "mutate"
                case .binding: return "binding"
                case .output: return "output"
            }
        }

        public var details: String {
            switch self {
                case .action(let action): return String(describing: action)
                case .mutation(let keyPath, let value, let property), .binding(let keyPath, let value, let property):
                    return "\(property)"

                case .output(let event): return String(describing: event)
            }
        }
    }
}

@dynamicMemberLookup
public class ComponentModel<C: Component> {

    let viewModel: ViewModel<C>

    init(viewModel: ViewModel<C>) {
        self.viewModel = viewModel
    }

    public var state: C.State { viewModel.state }

    public func mutate<Value>(_ keyPath: WritableKeyPath<C.State, Value>, _ value: Value, file: StaticString = #file, line: UInt = #line) {
        viewModel.mutate(keyPath, value: value, file: file, line: line)
    }

    public func present<PC: Component>(_ route: C.Route, as mode: PresentationMode, inNav: Bool, using component: PC.Type, create: () -> PC.State) {
        viewModel.present(route, as: mode, inNav: inNav, using: component, create: create)
    }

    public func output(_ event: C.Output, file: StaticString = #file, line: UInt = #line) {
        viewModel.output(event, file: file, line: line)
    }

    public subscript<Value>(dynamicMember keyPath: WritableKeyPath<C.State, Value>) -> Value {
        get { viewModel.state[keyPath: keyPath] }
        set { viewModel.mutate(keyPath, value: newValue) }
    }
}

extension ComponentModel {

    public func loadResource<ResourceState>(_ keyPath: WritableKeyPath<C.State, Resource<ResourceState>>, load: () async throws -> ResourceState) async {
        mutate(keyPath.appending(path: \.isLoading), true)
        do {
            let content = try await load()
            mutate(keyPath.appending(path: \.content), content)
            print("Loaded resource \(ResourceState.self):\n\(content)")
        } catch {
            mutate(keyPath.appending(path: \.error), error)
            print("Failed to load resource \(ResourceState.self)")
        }
        mutate(keyPath.appending(path: \.isLoading), false)
    }
}

extension ViewModel {

    private func scopeBinding<Value>(_ keyPath: WritableKeyPath<C.State, Value>) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { self.state[keyPath: keyPath] = $0 }
        )
    }
    func _scope<Child: Component>(state stateKeyPath: WritableKeyPath<C.State, Child.State>) -> ViewModel<Child> where Child.State: Equatable {
        ViewModel<Child>(state: scopeBinding(stateKeyPath))
    }

    func _scope<Child: Component>(state stateKeyPath: WritableKeyPath<C.State, Child.State?>, value: Child.State) -> ViewModel<Child> where Child.State: Equatable {
        let optionalBinding = scopeBinding(stateKeyPath)
        let binding = Binding<Child.State> {
            optionalBinding.wrappedValue ?? value
        } set: {
            optionalBinding.wrappedValue = $0
        }

        return ViewModel<Child>(state: binding)
    }

    public func scope<Child: Component>(state stateKeyPath: WritableKeyPath<C.State, Child.State>, event toAction: @escaping (Child.Output) -> C.Action) -> ViewModel<Child> where Child.State: Equatable {
        let viewModel = _scope(state: stateKeyPath) as ViewModel<Child>
        viewModel.listen { event in
            switch event.event {
                case .output(let output):
                    let action = toAction(output)
                    self.send(action)
                default:
                    break
            }
        }
        return viewModel
    }

    public func scope<Child: Component>(state stateKeyPath: WritableKeyPath<C.State, Child.State?>, value: Child.State, event toAction: @escaping (Child.Output) -> C.Action) -> ViewModel<Child> where Child.State: Equatable {
        let viewModel = _scope(state: stateKeyPath, value: value) as ViewModel<Child>
        viewModel.listen { event in
            switch event.event {
                case .output(let output):
                    let action = toAction(output)
                    self.send(action)
                default:
                    break
            }
        }
        return viewModel
    }

    public func scope<Child: Component>(state stateKeyPath: WritableKeyPath<C.State, Child.State?>, value: Child.State) -> ViewModel<Child> where Child.State: Equatable, Child.Output == Never {
        _scope(state: stateKeyPath, value: value)
    }

    public func scope<Child: Component>(state stateKeyPath: WritableKeyPath<C.State, Child.State>) -> ViewModel<Child> where Child.State: Equatable, Child.Output == Never {
        _scope(state: stateKeyPath)
    }
}