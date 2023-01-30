import Foundation
import SwiftUI
import Combine

class ComponentStore<Model: ComponentModel>: ObservableObject {

    private var stateBinding: Binding<Model.State>?
    private var ownedState: Model.State?
    var path: ComponentPath
    var componentName: String { Model.baseName }
    private var eventsInProgress = 0
    var previewTaskDelay: TimeInterval = 0
    let stateChanged = PassthroughSubject<Model.State, Never>()

    internal(set) var state: Model.State {
        get {
            ownedState ?? stateBinding!.wrappedValue
        }
        set {
            guard !areMaybeEqual(state, newValue) else { return }
            if let stateBinding {
                stateBinding.wrappedValue = newValue
            } else {
                ownedState = newValue
            }
            objectWillChange.send()
            stateChanged.send(newValue)
        }
    }

    let id = UUID()
    @Published var route: Model.Route?
    var modelContext: ComponentModelStore<Model>!
    var model: Model
    var cancellables: Set<AnyCancellable> = []
    private var mutations: [Mutation] = []
    var handledAppear = false
    var mutationAnimation: Animation?
    var sendGlobalEvents = true
    public var events = PassthroughSubject<Event, Never>()
    private var subscriptions: Set<AnyCancellable> = []
    var stateDump: String { dumpToString(state) }

    convenience init(state: Model.State, path: ComponentPath? = nil) {
        self.init(path: path)
        self.ownedState = state
    }

    convenience init(state: Binding<Model.State>, path: ComponentPath? = nil) {
        self.init(path: path)
        self.stateBinding = state
    }

    private init(path: ComponentPath?) {
        self.model = Model()
        self.path = path?.appending(Model.self) ?? ComponentPath(Model.self)
        self.modelContext = ComponentModelStore(store: self)
    }

    private func startEvent() {
        eventsInProgress += 1
    }

    fileprivate func sendEvent(type: EventType, start: Date, mutations: [Mutation], source: Source) {
        eventsInProgress -= 1
        if eventsInProgress < 0 {
            assertionFailure("Parent count is \(eventsInProgress), but should only be 0 or more")
        }
        let event = Event(type: type, componentPath: path, start: start, end: Date(), mutations: mutations, depth: eventsInProgress, source: source)
//        print("\(event.type.emoji) \(path) \(event.type.title): \(event.type.details)")
        events.send(event)

        guard sendGlobalEvents else { return }
        EventStore.shared.send(event)
    }

    func processAction(_ action: Model.Action, source: Source, sendEvents: Bool) {
        Task { @MainActor in
            await processAction(action, source: source, sendEvents: sendEvents)
        }
    }

    @MainActor
    func processAction(_ action: Model.Action, source: Source, sendEvents: Bool) async {
        let eventStart = Date()
        startEvent()
        mutations = []
        await model.handle(action: action, store: modelContext)
        if sendEvents {
            sendEvent(type: .action(action), start: eventStart, mutations: mutations, source: source)
        }
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
        await model.handle(input: input, store: modelContext)
        if sendEvents {
            sendEvent(type: .input(input), start: eventStart, mutations: mutations, source: source)
        }
    }

    func onOutput(_ handle: @escaping (Model.Output) -> Void) -> Self {
        self.onEvent { event in
            if case let .output(output) = event.type, let output = output as? Model.Output {
                handle(output)
            }
        }
    }

    func onEvent(_ handle: @escaping (Event) -> Void) -> Self {
        self.events.sink { event in
            handle(event)
        }
        .store(in: &cancellables)
        return self
    }
}

// MARK: View Accessors
extension ComponentStore {

    func send(_ action: Model.Action, animation: Animation? = nil, file: StaticString = #file, line: UInt = #line) {
        mutationAnimation = animation
        processAction(action, source: .capture(file: file, line: line), sendEvents: true)
        mutationAnimation = nil
    }

    @MainActor
    func binding<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, file: StaticString = #file, line: UInt = #line, onSet: ((Value) -> Model.Action?)? = nil) -> Binding<Value> {
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
                    await self.model.binding(keyPath: keyPath, store: self.modelContext)
                }

                if let onSet, let action = onSet(value) {
                    self.send(action, file: file, line: line)
                }
            }
        )
    }
}

// MARK: ComponentView Accessors
extension ComponentStore {

    @MainActor
    func appear(first: Bool) async {
        let start = Date()
        startEvent()
        mutations = []
        handledAppear = true
        await model.appear(store: modelContext)
        self.sendEvent(type: .appear(first: first), start: start, mutations: mutations, source: .capture())
    }
}

// MARK: Model Accessors
extension ComponentStore {

    func mutate<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, value: Value, animation: Animation? = nil, source: Source) {
        let start = Date()
        startEvent()
        // TODO: note that source from dynamicMember keyPath is not correct
//        let oldState = state
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
extension ComponentStore {

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

    // state binding and output
    func scope<Child: ComponentModel>(state binding: Binding<Child.State>, file: StaticString = #file, line: UInt = #line, output toInput: @escaping (Child.Output) -> Model.Input) -> ComponentStore<Child> {
        let store = ComponentStore<Child>(state: binding, path: self.path)
            .onOutput { [weak self] output in
                guard let self else { return }
                let input = toInput(output)
                self.processInput(input, source: .capture(file: file, line: line), sendEvents: false)
            }
        store.events.sink { [weak self] event in
            guard let self else { return }
            self.events.send(event)
        }
        .store(in: &store.subscriptions)
        return store
    }

    // state binding
    func scope<Child: ComponentModel>(state binding: Binding<Child.State>) -> ComponentStore<Child> where Child.Output == Never {
        let store = ComponentStore<Child>(state: binding, path: self.path)
        store.events.sink { [weak self] event in
            guard let self else { return }
            self.events.send(event)
        }
        .store(in: &store.subscriptions)
        return store
    }

    // statePath and output
    func scope<Child: ComponentModel>(statePath: WritableKeyPath<Model.State, Child.State>, file: StaticString = #file, line: UInt = #line, output toInput: @escaping (Child.Output) -> Model.Input) -> ComponentStore<Child> {
        scope(state: keyPathBinding(statePath), file: file, line: line, output: toInput)
    }

    // optional statePath and output
    func scope<Child: ComponentModel>(statePath: WritableKeyPath<Model.State, Child.State?>, value: Child.State, file: StaticString = #file, line: UInt = #line, output toInput: @escaping (Child.Output) -> Model.Input) -> ComponentStore<Child> {
        scope(state: optionalBinding(state: statePath, value: value), file: file, line: line, output: toInput)
    }

    // optional statePath
    func scope<Child: ComponentModel>(statePath: WritableKeyPath<Model.State, Child.State?>, value: Child.State) -> ComponentStore<Child> where Child.Output == Never {
        scope(state: optionalBinding(state: statePath, value: value))
    }

    // statePath
    func scope<Child: ComponentModel>(statePath: WritableKeyPath<Model.State, Child.State>) -> ComponentStore<Child> where Child.Output == Never {
        scope(state: keyPathBinding(statePath))
    }

    // state
    func scope<Child: ComponentModel>(state: Child.State) -> ComponentStore<Child> where Child.Output == Never {
        let store = ComponentStore<Child>(state: state, path: self.path)
        store.events.sink { [weak self] event in
            guard let self else { return }
            self.events.send(event)
        }
        .store(in: &store.subscriptions)
        return store
    }

    // state and output
    func scope<Child: ComponentModel>(state: Child.State, file: StaticString = #file, line: UInt = #line, output toInput: @escaping (Child.Output) -> Model.Input) -> ComponentStore<Child> {
        let store = ComponentStore<Child>(state: state, path: self.path)
            .onOutput { [weak self] output in
                guard let self else { return }
                let input = toInput(output)
                self.processInput(input, source: .capture(file: file, line: line), sendEvents: false)
            }
        store.events.sink { [weak self] event in
            guard let self else { return }
            self.events.send(event)
        }
        .store(in: &store.subscriptions)
        return store
    }
}
