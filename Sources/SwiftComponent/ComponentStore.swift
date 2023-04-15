import Foundation
import SwiftUI
import Combine

class ComponentStore<Model: ComponentModel> {

    private var stateBinding: Binding<Model.State>?
    private var ownedState: Model.State?
    var path: ComponentPath
    let graph: ComponentGraph
    var dependencies: ComponentDependencies
    var componentName: String { Model.baseName }
    private var eventsInProgress = 0
    var previewTaskDelay: TimeInterval = 0
    let stateChanged = PassthroughSubject<Model.State, Never>()
    let routeChanged = PassthroughSubject<Model.Route?, Never>()

    var state: Model.State {
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
            stateChanged.send(newValue)
        }
    }

    let id = UUID()
    var route: Model.Route? {
        didSet {
            routeChanged.send(route)
        }
    }
    var modelStore: ComponentModelStore<Model>!
    var model: Model
    var cancellables: Set<AnyCancellable> = []
    private var mutations: [Mutation] = []
    var handledAppear = false
    var handledDisappear = false
    var mutationAnimation: Animation?
    var sendGlobalEvents = true
    private var lastSource: Source? // used to get at the original source of a mutation, due to no source info on dynamic member lookup
    public var events = PassthroughSubject<Event, Never>()
    private var subscriptions: Set<AnyCancellable> = []
    var stateDump: String { dumpToString(state) }

    convenience init(state: Model.State, path: ComponentPath? = nil, graph: ComponentGraph, route: Model.Route? = nil) {
        self.init(path: path, graph: graph, route: route)
        self.ownedState = state
    }

    convenience init(state: Binding<Model.State>, path: ComponentPath? = nil, graph: ComponentGraph, route: Model.Route? = nil) {
        self.init(path: path, graph: graph, route: route)
        self.stateBinding = state
    }

    private init(path: ComponentPath?, graph: ComponentGraph , route: Model.Route? = nil) {
        self.model = Model()
        self.graph = graph
        self.path = path?.appending(Model.self) ?? ComponentPath(Model.self)
        self.dependencies = ComponentDependencies()
        self.modelStore = ComponentModelStore(store: self)
        if let route = route {
            model.connect(route: route, store: modelStore)
            self.route = route
        }
        events.sink { [weak self] event in
            self?.model.handle(event: event)
        }
        .store(in: &subscriptions)
    }

    private func startEvent() {
        eventsInProgress += 1
    }

    fileprivate func sendEvent(type: EventType, start: Date, mutations: [Mutation], source: Source) {
        eventsInProgress -= 1
        if eventsInProgress < 0 {
            assertionFailure("Parent count is \(eventsInProgress), but should only be 0 or more")
        }
        let event = Event(type: type, storeID: id, componentPath: path, start: start, end: Date(), mutations: mutations, depth: eventsInProgress, source: source)
        events.send(event)
        guard sendGlobalEvents else { return }
        EventStore.shared.send(event)
    }

    func processAction(_ action: Model.Action, source: Source) {
        lastSource = source
        Task { @MainActor in
            await processAction(action, source: source)
        }
    }

    @MainActor
    func processAction(_ action: Model.Action, source: Source) async {
        let eventStart = Date()
        startEvent()
        mutations = []
        await model.handle(action: action, store: modelStore)
        sendEvent(type: .action(action), start: eventStart, mutations: mutations, source: source)
    }

    func processInput(_ input: Model.Input, source: Source) {
        lastSource = source
        Task { @MainActor in
            await processInput(input, source: source)
        }
    }

    @MainActor
    func processInput(_ input: Model.Input, source: Source) async {
        let eventStart = Date()
        startEvent()
        mutations = []
        await model.handle(input: input, store: modelStore)
        sendEvent(type: .input(input), start: eventStart, mutations: mutations, source: source)
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
        processAction(action, source: .capture(file: file, line: line))
        mutationAnimation = nil
    }

    @MainActor
    func binding<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, file: StaticString = #file, line: UInt = #line, onSet: ((Value) -> Model.Action?)? = nil) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { value in
                let start = Date()
                let oldState = self.state
                let oldValue = self.state[keyPath: keyPath]
                // don't continue if change doesn't lead to state change
                guard !areMaybeEqual(oldValue, value) else { return }

                self.startEvent()
                //                print("Changed \(self)\n\(self.state[keyPath: keyPath])\nto\n\(value)\n")
                self.state[keyPath: keyPath] = value

                //print(diff(oldState, self.state) ?? "  No state changes")

                Task { @MainActor in
                    await self.model.binding(keyPath: keyPath, store: self.modelStore)
                }

                let mutation = Mutation(keyPath: keyPath, value: value, oldState: oldState)
                self.sendEvent(type: .binding(mutation), start: start, mutations: [mutation], source: .capture(file: file, line: line))

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
    func appear(first: Bool, file: StaticString = #file, line: UInt = #line) async {
        let start = Date()
        startEvent()
        mutations = []
        handledAppear = true
        await model.appear(store: modelStore)
        self.sendEvent(type: .appear(first: first), start: start, mutations: mutations, source: .capture(file: file, line: line))
    }

    func disappear(file: StaticString = #file, line: UInt = #line) {
        Task { @MainActor in
            let start = Date()
            startEvent()
            mutations = []
            handledDisappear = true
            await model.disappear(store: modelStore)
            self.sendEvent(type: .disappear, start: start, mutations: mutations, source: .capture(file: file, line: line))
        }
    }
}

// MARK: Model Accessors
extension ComponentStore {

    func mutate<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, value: Value, animation: Animation? = nil, source: Source?) {
        // we can't get the source in dynamic member lookup, so just use the original action or input
        let source = source ?? lastSource ?? .capture()
        let start = Date()
        startEvent()

        let oldState = state
        let mutation = Mutation(keyPath: keyPath, value: value, oldState: oldState)
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

    @MainActor
    func present(_ route: Model.Route, source: Source) {
        _ = model.connect(route: route, store: modelStore)
        self.route = route
        startEvent()
        sendEvent(type: .route(route), start: Date(), mutations: [], source: source)
    }

    func dismissRoute(source: Source) {
        if route != nil {
            DispatchQueue.main.async {
                self.startEvent()
                self.route = nil
                self.sendEvent(type: .dismissRoute, start: Date(), mutations: [], source: source)
            }
        }
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

    private func connectTo<Child: ComponentModel>(_ store: ComponentStore<Child>, output handleOutput: @escaping (Child.Output) -> Void) -> ComponentStore<Child> {
        store.events.sink { [weak self] event in
            guard let self else { return }
            self.events.send(event)
        }
        .store(in: &store.subscriptions)

        return store.onOutput { output in
            handleOutput(output)
        }
    }

    private func connectTo<Child: ComponentModel>(_ store: ComponentStore<Child>) -> ComponentStore<Child> where Child.Output == Never {
        store.events.sink { [weak self] event in
            guard let self else { return }
            self.events.send(event)
        }
        .store(in: &store.subscriptions)

        return store
    }

    // state binding and output -> input
    func scope<Child: ComponentModel>(state binding: Binding<Child.State>, file: StaticString = #file, line: UInt = #line, output toInput: @escaping (Child.Output) -> Model.Input) -> ComponentStore<Child> {
        connectTo(ComponentStore<Child>(state: binding, path: self.path, graph: graph)) { [weak self] output in
            guard let self else { return }
            let input = toInput(output)
            self.processInput(input, source: .capture(file: file, line: line))
        }
    }

    // statePath and output -> input
    func scope<Child: ComponentModel>(statePath: WritableKeyPath<Model.State, Child.State>, file: StaticString = #file, line: UInt = #line, output toInput: @escaping (Child.Output) -> Model.Input) -> ComponentStore<Child> {
        scope(state: keyPathBinding(statePath), file: file, line: line, output: toInput)
    }

    // optional statePath and output -> input
    func scope<Child: ComponentModel>(statePath: WritableKeyPath<Model.State, Child.State?>, value: Child.State, file: StaticString = #file, line: UInt = #line, output toInput: @escaping (Child.Output) -> Model.Input) -> ComponentStore<Child> {
        scope(state: optionalBinding(state: statePath, value: value), file: file, line: line, output: toInput)
    }

    // state and output -> input
    func scope<Child: ComponentModel>(state: Child.State, file: StaticString = #file, line: UInt = #line, output toInput: @escaping (Child.Output) -> Model.Input) -> ComponentStore<Child> {
        connectTo(ComponentStore<Child>(state: state, path: self.path, graph: graph)) { [weak self] output in
            guard let self else { return }
            let input = toInput(output)
            self.processInput(input, source: .capture(file: file, line: line))
        }
    }

    // state binding and output -> output
    func scope<Child: ComponentModel>(state binding: Binding<Child.State>, file: StaticString = #file, line: UInt = #line, output toOutput: @escaping (Child.Output) -> Model.Output) -> ComponentStore<Child> {
        connectTo(ComponentStore<Child>(state: binding, path: self.path, graph: graph)) { [weak self] output in
            guard let self else { return }
            let output = toOutput(output)
            self.output(output, source: .capture(file: file, line: line))
        }
    }

    // statePath and output -> output
    func scope<Child: ComponentModel>(statePath: WritableKeyPath<Model.State, Child.State>, file: StaticString = #file, line: UInt = #line, output toOutput: @escaping (Child.Output) -> Model.Output) -> ComponentStore<Child> {
        scope(state: keyPathBinding(statePath), file: file, line: line, output: toOutput)
    }

    // optional statePath and output -> output
    func scope<Child: ComponentModel>(statePath: WritableKeyPath<Model.State, Child.State?>, value: Child.State, file: StaticString = #file, line: UInt = #line, output toOutput: @escaping (Child.Output) -> Model.Output) -> ComponentStore<Child> {
        scope(state: optionalBinding(state: statePath, value: value), file: file, line: line, output: toOutput)
    }

    // state and output -> output
    func scope<Child: ComponentModel>(state: Child.State, file: StaticString = #file, line: UInt = #line, output toOutput: @escaping (Child.Output) -> Model.Output) -> ComponentStore<Child> {
        connectTo(ComponentStore<Child>(state: state, path: self.path, graph: graph)) { [weak self] output in
            guard let self else { return }
            let output = toOutput(output)
            self.output(output, source: .capture(file: file, line: line))
        }
    }

    // state binding and output -> Never
    func scope<Child: ComponentModel>(state binding: Binding<Child.State>, file: StaticString = #file, line: UInt = #line) -> ComponentStore<Child> where Child.Output == Never {
        connectTo(ComponentStore<Child>(state: binding, path: self.path, graph: graph))
    }

    // statePath and output -> Never
    func scope<Child: ComponentModel>(statePath: WritableKeyPath<Model.State, Child.State>, file: StaticString = #file, line: UInt = #line) -> ComponentStore<Child> where Child.Output == Never {
        scope(state: keyPathBinding(statePath), file: file, line: line)
    }

    // optional statePath and output -> Never
    func scope<Child: ComponentModel>(statePath: WritableKeyPath<Model.State, Child.State?>, value: Child.State, file: StaticString = #file, line: UInt = #line) -> ComponentStore<Child> where Child.Output == Never {
        scope(state: optionalBinding(state: statePath, value: value), file: file, line: line)
    }

    // state and output -> Never
    func scope<Child: ComponentModel>(state: Child.State, file: StaticString = #file, line: UInt = #line) -> ComponentStore<Child> where Child.Output == Never {
        connectTo(ComponentStore<Child>(state: state, path: self.path, graph: graph))
    }
}
