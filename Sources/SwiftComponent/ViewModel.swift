//
//  File.swift
//  
//
//  Created by Yonas Kolb on 10/11/2022.
//

import Foundation
import SwiftUI
import Combine

@dynamicMemberLookup
public class ViewModel<Model: ComponentModel>: ObservableObject {

    private var stateBinding: Binding<Model.State>?
    private var ownedState: Model.State?
    public var path: ComponentPath
    public var componentName: String { Model.baseName }
    private var eventsInProgress = 0
    var previewTaskDelay: TimeInterval = 0

    public internal(set) var state: Model.State {
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

    let id = UUID()
    @Published var route: Model.Route?
    var modelContext: ModelContext<Model>!
    var model: Model
    var cancellables: Set<AnyCancellable> = []
    private var mutations: [Mutation] = []
    var handledAppear = false
    var mutationAnimation: Animation?
    var sendGlobalEvents = true
    public var events = PassthroughSubject<ComponentEvent, Never>()
    private var subscriptions: Set<AnyCancellable> = []
    var stateDump: String { dumpToString(state) }

    public convenience init(state: Model.State, path: ComponentPath? = nil) {
        self.init(path: path)
        self.ownedState = state
    }

    public convenience init(state: Binding<Model.State>, path: ComponentPath? = nil) {
        self.init(path: path)
        self.stateBinding = state
    }

    private init(path: ComponentPath?) {
        self.model = Model()
        self.path = path?.appending(Model.self) ?? ComponentPath(Model.self)
        self.modelContext = ModelContext(viewModel: self)
    }

    private func startEvent() {
        eventsInProgress += 1
    }

    fileprivate func sendEvent(type: EventType, start: Date, mutations: [Mutation], source: Source) {
        eventsInProgress -= 1
        if eventsInProgress < 0 {
            assertionFailure("Parent count is \(eventsInProgress), but should only be 0 or more")
        }
        let event = ComponentEvent(type: type, componentPath: path, start: start, end: Date(), mutations: mutations, depth: eventsInProgress, source: source)
        print("\(event.type.emoji) \(path) \(event.type.title): \(event.type.details)")
        events.send(event)

        guard sendGlobalEvents else { return }

        viewModelEvents.append(event)
    }

    func processInput(_ input: Model.Input, source: Source, sendEvents: Bool) {
        Task { @MainActor in
            await processInput(input, source: source, sendEvents: sendEvents)
        }
    }

    @MainActor
    func processInput(_ input: Model.Input, source: Source, sendEvents: Bool) async {
        let eventStart = Date()
        startEvent()
        mutations = []
        await model.handle(input: input, model: modelContext)
        if sendEvents {
            sendEvent(type: .input(input), start: eventStart, mutations: mutations, source: source)
        }
    }

    public subscript<Value>(dynamicMember keyPath: KeyPath<Model.State, Value>) -> Value {
        self.state[keyPath: keyPath]
    }

}

// MARK: View Accessors
extension ViewModel {

    public func send(_ input: Model.Input, animation: Animation? = nil, file: StaticString = #file, line: UInt = #line) {
        mutationAnimation = animation
        processInput(input, source: .capture(file: file, line: line), sendEvents: true)
        mutationAnimation = nil
    }

    public func binding<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, file: StaticString = #file, line: UInt = #line, onSet: ((Value) -> Model.Input?)? = nil) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { value in
                let start = Date()
                self.startEvent()
                // don't continue if change doesn't lead to state change
                guard !areMaybeEqual(self.state[keyPath: keyPath], value) else { return }

                //                print("Changed \(self)\n\(self.state[keyPath: keyPath])\nto\n\(value)\n")
                self.state[keyPath: keyPath] = value

                let mutation = Mutation(keyPath: keyPath, value: value)
                self.sendEvent(type: .binding(mutation), start: start, mutations: [mutation], source: .capture(file: file, line: line))

                //print(diff(oldState, self.state) ?? "  No state changes")

                Task { @MainActor in
                    await self.model.binding(keyPath: keyPath, model: self.modelContext)
                }

                if let onSet = onSet, let action = onSet(value) {
                    self.send(action, file: file, line: line)
                }
            }
        )
    }
}

// MARK: ComponentView Accessors
extension ViewModel {

    @MainActor
    func appear() async {
        let start = Date()
        startEvent()
        mutations = []
        handledAppear = true
        await model.appear(model: modelContext)
        self.sendEvent(type: .appear, start: start, mutations: mutations, source: .capture())
    }
}

// MARK: Model Accessors
extension ViewModel {

    func mutate<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, value: Value, source: Source, animation: Animation? = nil) {
        let start = Date()
        startEvent()
        // TODO: note that source from dynamicMember keyPath is not correct
        let oldState = state
        let mutation = Mutation(keyPath: keyPath, value: value)
        self.mutations.append(mutation)
        if let animation {
            withAnimation(animation) {
                self.state[keyPath: keyPath] = value
            }
        } else {
            self.state[keyPath: keyPath] = value
        }
        sendEvent(type: .mutation(mutation), start: start, mutations: [mutation], source: source)
        //print(diff(oldState, self.state) ?? "  No state changes")
    }

    func output(_ event: Model.Output, source: Source) {
        startEvent()
        self.sendEvent(type: .output(event), start: Date(), mutations: [], source: source)
    }

    @MainActor
    func task<R>(_ name: String, source: Source, _ task: () async -> R) async -> R {
        let start = Date()
        startEvent()
        mutations = []
        let value = await task()
        let result = TaskResult(name: name, result: .success(value))
        if previewTaskDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 * previewTaskDelay))
        }
        sendEvent(type: .task(result), start: start, mutations: mutations, source: source)
        return value
    }

    @MainActor
    func task<R>(_ name: String, source: Source, _ task: () async throws -> R, catch catchError: (Error) -> Void) async {
        let start = Date()
        startEvent()
        mutations = []
        let result: TaskResult
        do {
            let value = try await task()
            result = TaskResult(name: name, result: .success(value))
        } catch {
            catchError(error)
            result = TaskResult(name: name, result: .failure(error))
        }
        if previewTaskDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 * previewTaskDelay))
        }
        sendEvent(type: .task(result), start: start, mutations: mutations, source: source)
    }

    func present(_ route: Model.Route, source: Source) {
        self.route = route
        startEvent()
        sendEvent(type: .route(route), start: Date(), mutations: [], source: source)
    }

    func dismissRoute(source: Source) {
        //TODO: send event
        self.route = nil
    }
}

// MARK: Scoping
extension ViewModel {

    private func keyPathBinding<Value>(_ keyPath: WritableKeyPath<Model.State, Value>) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { self.state[keyPath: keyPath] = $0 }
        )
    }

    private func optionalBinding<ChildState>(state stateKeyPath: WritableKeyPath<Model.State, ChildState?>, value: ChildState) -> Binding<ChildState> {
        let optionalBinding = keyPathBinding(stateKeyPath)
        return Binding<ChildState> {
            optionalBinding.wrappedValue ?? value
        } set: {
            optionalBinding.wrappedValue = $0
        }
    }

    private func scopedViewModel<Child: ComponentModel>(_ binding: Binding<Child.State>, output toInput: @escaping (Child.Output) -> Model.Input, source: Source) -> ViewModel<Child> {
        let viewModel = ViewModel<Child>(state: binding, path: self.path)
        viewModel.events.sink { [weak self] event in
            guard let self else { return }
            self.events.send(event)
            switch event.type {
                case .output(let output):
                    if let output = output as? Child.Output {
                        let action = toInput(output)
                        self.processInput(action, source: source, sendEvents: false)
                    }
                default:
                    break
            }
        }
        .store(in: &viewModel.subscriptions)
        return viewModel
    }

    private func scopedViewModel<Child: ComponentModel>(_ binding: Binding<Child.State>) -> ViewModel<Child> where Child.Output == Never {
        let viewModel = ViewModel<Child>(state: binding, path: self.path)
        viewModel.events.sink { [weak self] event in
            guard let self else { return }
            self.events.send(event)
        }
        .store(in: &viewModel.subscriptions)
        return viewModel
    }

    // statePath and output
    public func scope<Child: ComponentModel>(statePath: WritableKeyPath<Model.State, Child.State>, file: StaticString = #file, line: UInt = #line, output toInput: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> {
        scopedViewModel(keyPathBinding(statePath), output: toInput, source: .capture(file: file, line: line))
    }

    // optional statePath and output
    public func scope<Child: ComponentModel>(statePath: WritableKeyPath<Model.State, Child.State?>, value: Child.State, file: StaticString = #file, line: UInt = #line, output toInput: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> {
        scopedViewModel(optionalBinding(state: statePath, value: value), output: toInput, source: .capture(file: file, line: line))
    }

    // optional statePath
    public func scope<Child: ComponentModel>(statePath: WritableKeyPath<Model.State, Child.State?>, value: Child.State) -> ViewModel<Child> where Child.Output == Never {
        scopedViewModel(optionalBinding(state: statePath, value: value))
    }

    // statePath
    public func scope<Child: ComponentModel>(statePath: WritableKeyPath<Model.State, Child.State>) -> ViewModel<Child> where Child.Output == Never {
        scopedViewModel(keyPathBinding(statePath))
    }

    // state
    public func scope<Child: ComponentModel>(state: Child.State) -> ViewModel<Child> where Child.Output == Never {
        let viewModel = ViewModel<Child>(state: state, path: self.path)
        viewModel.events.sink { [weak self] event in
            guard let self else { return }
            self.events.send(event)
        }
        .store(in: &viewModel.subscriptions)
        return viewModel
    }

    // state and output
    public func scope<Child: ComponentModel>(state: Child.State, file: StaticString = #file, line: UInt = #line, output toInput: @escaping (Child.Output) -> Model.Input) -> ViewModel<Child> {
        let viewModel = ViewModel<Child>(state: state, path: self.path)
        viewModel.events.sink { [weak self] event in
            guard let self else { return }
            self.events.send(event)

            switch event.type {
                case .output(let output):
                    if let output = output as? Child.Output {
                        let action = toInput(output)
                        self.processInput(action, source: .capture(file: file, line: line), sendEvents: false)
                    }
                default:
                    break
            }
        }
        .store(in: &viewModel.subscriptions)
        return viewModel
    }
}
