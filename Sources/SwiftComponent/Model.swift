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

public struct ComponentPath: CustomStringConvertible, Equatable {
    public static func == (lhs: ComponentPath, rhs: ComponentPath) -> Bool {
        lhs.string == rhs.string
    }

    public var suffix: String?
    public let path: [any Component.Type]

    var pathString: String {
        path.map { $0.name }.joined(separator: "/")
    }

    public var string: String {
        var string = pathString
        if let suffix = suffix {
            string += "\(suffix)"
        }
        return string
    }

    public var description: String { string }

    init(_ component: any Component.Type) {
        self.path = [component]
    }

    init(_ path: [any Component.Type]) {
        self.path = path
    }

    func contains(_ path: ComponentPath) -> Bool {
        self.pathString.hasPrefix(path.pathString)
    }

    func appending(_ component: any Component.Type) -> ComponentPath {
        ComponentPath(path + [component])
    }

    var parent: ComponentPath? {
        if path.count > 1 {
            return ComponentPath(path.dropLast())
        } else {
            return nil
        }
    }

    func relative(to component: ComponentPath) -> ComponentPath {
        guard contains(component) else { return self }
        let difference = path.count - component.path.count 
        return ComponentPath(Array(path.dropFirst(difference)))
    }

    var droppingRoot: ComponentPath? {
        if !path.isEmpty {
            return ComponentPath(Array(path.dropFirst()))
        } else {
            return nil
        }
    }
}

public struct Mutation<State>: Identifiable {
    public let keyPath: PartialKeyPath<State>
    public let value: Any
    public let property: String
    public var valueType: String { String(describing: type(of: value)) }
    public let id = UUID()

    init<T>(keyPath: KeyPath<State, T>, value: T) {
        self.keyPath = keyPath
        self.value = value
        self.property = keyPath.propertyName ?? "self"
    }
}

@dynamicMemberLookup
public class ViewModel<C: Component>: ObservableObject {

    private var stateBinding: Binding<C.State>?
    private var ownedState: C.State?
    public var path: ComponentPath
    public var componentName: String { C.name }

    public internal(set) var state: C.State {
        get {
            ownedState ?? stateBinding!.wrappedValue
        }
        set {
            guard !areMaybeEqual(state, newValue) else { return }
            if let stateBinding = stateBinding {
                stateBinding.wrappedValue = newValue
            } else {
                ownedState = newValue
            }
            objectWillChange.send()
        }
    }

    @Published public var route: PresentedRoute<C.Route>?
    let id = UUID()
    
    var componentModel: ComponentModel<C>!
    var component: C
    var cancellables: Set<AnyCancellable> = []
    private var mutations: [Mutation<C.State>] = []
    var handledTask = false
    var mutationAnimation: Animation?
    var sendEvents = true
    public var events = PassthroughSubject<Event<C>, Never>()
    private var subscriptions: Set<AnyCancellable> = []
    var stateDump: String { dumpToString(state) }

    public init(state: C.State) {
        self.ownedState = state
        self.component = C()
        self.path = .init(C.self)
        self.componentModel = ComponentModel(viewModel: self)
    }

    public init(state: Binding<C.State>, path: ComponentPath? = nil) {
        self.stateBinding = state
        self.component = C()
        self.path = path?.appending(C.self) ?? ComponentPath(C.self)
        self.componentModel = ComponentModel(viewModel: self)
    }

    fileprivate func sendEvent(_ eventType: Event<C>.EventType, sourceLocation: SourceLocation) {
        let event = Event<C>(eventType, componentPath: path, sourceLocation: sourceLocation)
        print("\(event.type.anyEvent.emoji) \(path) \(event.type.title): \(event.type.details)")
        events.send(event)

        guard sendEvents else { return }

        viewModelEvents.append(AnyEvent(event))
    }

    public func send(_ action: C.Action, animation: Animation? = nil, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line) {
        mutationAnimation = animation
        handleAction(action, sourceLocation: .capture(file: file, fileID: fileID, line: line))
        mutationAnimation = nil
    }

    func handleAction(_ action: C.Action, sourceLocation: SourceLocation) {
        Task { @MainActor in
            await handleAction(action, sourceLocation: sourceLocation)
        }
    }

    @MainActor
    func handleAction(_ action: C.Action, sourceLocation: SourceLocation) async {
        mutations = []
        await component.handle(action: action, model: componentModel)
        sendEvent(.action(action, mutations), sourceLocation: sourceLocation)
    }

    func mutate<Value>(_ keyPath: WritableKeyPath<C.State, Value>, value: Value, sourceLocation: SourceLocation, animation: Animation? = nil) {
        // TODO: note that sourceLocation from dynamicMember keyPath is not correct
        let oldState = state
        let mutation = Mutation<C.State>(keyPath: keyPath, value: value)
        self.mutations.append(mutation)
        if let animation {
            withAnimation(animation) {
                self.state[keyPath: keyPath] = value
            }
        } else {
            self.state[keyPath: keyPath] = value
        }
        //print(diff(oldState, self.state) ?? "  No state changes")
    }

    public func binding<Value>(_ keyPath: WritableKeyPath<C.State, Value>, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line, onSet: ((Value) -> C.Action?)? = nil) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { value in

                // don't continue if change doesn't lead to state change
                guard !areMaybeEqual(self.state[keyPath: keyPath], value) else { return }

//                print("Changed \(self)\n\(self.state[keyPath: keyPath])\nto\n\(value)\n")
                self.state[keyPath: keyPath] = value

                let mutation = Mutation<C.State>(keyPath: keyPath, value: value)
                self.sendEvent(.binding(mutation), sourceLocation: .capture(file: file, fileID: fileID, line: line))

                //print(diff(oldState, self.state) ?? "  No state changes")

                Task { @MainActor in
                    await self.component.handleBinding(keyPath: keyPath, model: self.componentModel)
                }

                if let onSet = onSet, let action = onSet(value) {
                    self.send(action, file: file, fileID: fileID, line: line)
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
        mutations = []
        handledTask = true
        await component.task(model: componentModel)
        if handledTask {
            self.sendEvent(.viewTask(mutations), sourceLocation: .capture())
        }
    }

    func output(_ event: C.Output, sourceLocation: SourceLocation) {
        self.sendEvent(.output(event), sourceLocation: sourceLocation)
    }

    @MainActor
    func task<R>(_ name: String, sourceLocation: SourceLocation, _ task: () async -> R) async -> R {
        let start = Date()
        let value = await task()
        sendEvent(.task(TaskResult(name: name, result: .success(value), start: start, end: Date())), sourceLocation: sourceLocation)
        return value
    }

    @MainActor
    func task<R>(_ name: String, sourceLocation: SourceLocation, _ task: () async throws -> R, catch catchError: (Error) -> Void) async {
        let start = Date()
        do {
            let value = try await task()
            sendEvent(.task(TaskResult(name: name, result: .success(value), start: start, end: Date())), sourceLocation: sourceLocation)
        } catch {
            catchError(error)
            sendEvent(.task(TaskResult(name: name, result: .failure(error), start: start, end: Date())), sourceLocation: sourceLocation)
        }
    }

    public subscript<Value>(dynamicMember keyPath: KeyPath<C.State, Value>) -> Value {
      self.state[keyPath: keyPath]
    }
}

@dynamicMemberLookup
public class ComponentModel<C: Component> {

    let viewModel: ViewModel<C>

    init(viewModel: ViewModel<C>) {
        self.viewModel = viewModel
    }

    var state: C.State { viewModel.state }

    public func mutate<Value>(_ keyPath: WritableKeyPath<C.State, Value>, _ value: Value, animation: Animation? = nil, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line) {
        viewModel.mutate(keyPath, value: value, sourceLocation: .capture(file: file, fileID: fileID, line: line), animation: animation)
    }

    public func present<PC: Component>(_ route: C.Route, as mode: PresentationMode, inNav: Bool, using component: PC.Type, create: () -> PC.State) {
        viewModel.present(route, as: mode, inNav: inNav, using: component, create: create)
    }

    public func output(_ event: C.Output, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line) {
        viewModel.output(event, sourceLocation: .capture(file: file, fileID: fileID, line: line))
    }

    public subscript<Value>(dynamicMember keyPath: WritableKeyPath<C.State, Value>) -> Value {
        get { viewModel.state[keyPath: keyPath] }
        set {
            // TODO: can't capture source location
            // https://forums.swift.org/t/add-default-parameter-support-e-g-file-to-dynamic-member-lookup/58490/2
            viewModel.mutate(keyPath, value: newValue, sourceLocation: .capture(file: #file, fileID: #fileID, line: #line))
        }
    }

    public func task(_ name: String, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line, _ task: () async -> Void) async {
        await viewModel.task(name, sourceLocation: .capture(file: file, fileID: fileID, line: line), task)
    }

    public func task<R>(_ name: String, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line, _ task: () async throws -> R, catch catchError: (Error) -> Void) async {
        await viewModel.task(name, sourceLocation: .capture(file: file, fileID: fileID, line: line), task, catch: catchError)
    }
}

extension ComponentModel {

    @MainActor
    public func loadResource<ResourceState>(_ keyPath: WritableKeyPath<C.State, Resource<ResourceState>>, animation: Animation? = nil, load: @MainActor () async throws -> ResourceState) async {
        mutate(keyPath.appending(path: \.isLoading), true, animation: animation)
        let name = "get \(keyPath.propertyName ?? "resource")"
        await task(name) {
            let content = try await load()
            mutate(keyPath.appending(path: \.content), content, animation: animation)
        } catch: { error in
            mutate(keyPath.appending(path: \.error), error, animation: animation)
        }
        mutate(keyPath.appending(path: \.isLoading), false, animation: animation)
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
        ViewModel<Child>(state: scopeBinding(stateKeyPath), path: self.path)
    }

    func _scope<Child: Component>(state stateKeyPath: WritableKeyPath<C.State, Child.State?>, value: Child.State) -> ViewModel<Child> where Child.State: Equatable {
        let optionalBinding = scopeBinding(stateKeyPath)
        let binding = Binding<Child.State> {
            optionalBinding.wrappedValue ?? value
        } set: {
            optionalBinding.wrappedValue = $0
        }

        return ViewModel<Child>(state: binding, path: self.path)
    }

    public func scope<Child: Component>(state stateKeyPath: WritableKeyPath<C.State, Child.State>, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line, event toAction: @escaping (Child.Output) -> C.Action) -> ViewModel<Child> where Child.State: Equatable {
        let viewModel = _scope(state: stateKeyPath) as ViewModel<Child>
        viewModel.events.sink { [weak self] event in
            guard let self else { return }
            switch event.type {
                case .output(let output):
                    let action = toAction(output)
                    self.handleAction(action, sourceLocation: .capture(file: file, fileID: fileID, line: line))
                default:
                    break
            }
        }
        .store(in: &viewModel.subscriptions)
        return viewModel
    }

    public func scope<Child: Component>(state stateKeyPath: WritableKeyPath<C.State, Child.State?>, value: Child.State, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line, event toAction: @escaping (Child.Output) -> C.Action) -> ViewModel<Child> where Child.State: Equatable {
        let viewModel = _scope(state: stateKeyPath, value: value) as ViewModel<Child>
        viewModel.events.sink { [weak self] event in
            guard let self else { return }
            switch event.type {
                case .output(let output):
                    let action = toAction(output)
                    self.handleAction(action, sourceLocation: .capture(file: file, fileID: fileID, line: line))
                default:
                    break
            }
        }
        .store(in: &viewModel.subscriptions)
        return viewModel
    }

    public func scope<Child: Component>(state stateKeyPath: WritableKeyPath<C.State, Child.State?>, value: Child.State) -> ViewModel<Child> where Child.State: Equatable, Child.Output == Never {
        _scope(state: stateKeyPath, value: value)
    }

    public func scope<Child: Component>(state stateKeyPath: WritableKeyPath<C.State, Child.State>) -> ViewModel<Child> where Child.State: Equatable, Child.Output == Never {
        _scope(state: stateKeyPath)
    }
}
