import Foundation
import SwiftUI
import Combine


class ComponentStore<Model: ComponentModel> {

    enum StateStorage {
        case root(Model.State)
        case binding(Binding<Model.State>)

        var state: Model.State {
            get {
                switch self {
                case .root(let state): return state
                case .binding(let binding): return binding.wrappedValue
                }
            }
            set {
                switch self {
                case .root:
                    self = .root(newValue)
                case .binding(let binding):
                    binding.wrappedValue = newValue
                }
            }
        }
    }

    private var stateStorage: StateStorage
    var path: ComponentPath
    let graph: ComponentGraph
    var dependencies: ComponentDependencies
    var componentName: String { Model.baseName }
    private var eventsInProgress = 0
    var previewTaskDelay: TimeInterval = 0
    private var tasksByID: [String: CancellableTask] = [:]
    private var tasks: [CancellableTask] = []
    private var appearanceTask: CancellableTask?
    let stateChanged = PassthroughSubject<Model.State, Never>()
    let routeChanged = PassthroughSubject<Model.Route?, Never>()

    var state: Model.State {
        get {
            stateStorage.state
        }
        set {
            guard !areMaybeEqual(state, newValue) else { return }
            stateStorage.state = newValue
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

    init(state: StateStorage, path: ComponentPath?, graph: ComponentGraph, route: Model.Route? = nil) {
        self.stateStorage = state
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

    deinit {
        modelStore.cancellables = []
        cancelTasks()
    }

    func cancelTasks() {
        tasksByID.forEach { $0.value.cancel() }
        tasksByID = [:]
        tasks.forEach { $0.cancel() }
        tasks = []
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
        addTask { @MainActor [weak self]  in
            guard let self else { return }
            await self.processAction(action, source: source)
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
        addTask { @MainActor [weak self]  in
            guard let self else { return }
            await self.processInput(input, source: source)
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

    func onOutput(_ handle: @escaping (Model.Output, Event) -> Void) -> Self {
        self.onEvent { event in
            if case let .output(output) = event.type, let output = output as? Model.Output {
                handle(output, event)
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

                self.addTask { @MainActor [weak self]  in
                    guard let self else { return }
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

    func appear(first: Bool, file: StaticString = #file, line: UInt = #line) {
        appearanceTask = addTask { @MainActor [weak self]  in
            await self?.appear(first: first, file: file, line: line)
        }
    }

    func appear(first: Bool, file: StaticString = #file, line: UInt = #line) async {
        let start = Date()
        startEvent()
        mutations = []
        handledAppear = true
        if let store = modelStore {
            await model.appear(store: store)
        }
        sendEvent(type: .appear(first: first), start: start, mutations: self.mutations, source: .capture(file: file, line: line))
    }

    func disappear(file: StaticString = #file, line: UInt = #line) {
        addTask { @MainActor [weak self]  in
            guard let self else { return }
            let start = Date()
            self.startEvent()
            self.mutations = []
            self.handledDisappear = true
            await self.model.disappear(store: self.modelStore)
            self.sendEvent(type: .disappear, start: start, mutations: self.mutations, source: .capture(file: file, line: line))

            appearanceTask?.cancel()
            appearanceTask = nil
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
    func task<R>(_ name: String, cancellable: Bool, source: Source,  _ task: @escaping () async -> R) async -> R {
        let cancelID = name

        let start = Date()
        startEvent()
        mutations = []
        if cancellable {
            cancelTask(cancelID: cancelID)
        }
        let task = Task { @MainActor in
            await task()
        }
        addTask(task, cancelID: cancelID)
        let value = await task.value
        tasksByID[cancelID] = nil
        let result = TaskResult(name: name, result: .success(value))
        if previewTaskDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 * previewTaskDelay))
        }
        sendEvent(type: .task(result), start: start, mutations: mutations, source: source)
        return value
    }

    @MainActor
    func task<R>(_ name: String, cancellable: Bool, source: Source, _ task: @escaping () async throws -> R, catch catchError: (Error) -> Void) async {
        let cancelID = name
        let start = Date()
        startEvent()
        mutations = []
        let result: TaskResult
        do {
            if cancellable {
                cancelTask(cancelID: cancelID)
            }

            let task = Task { @MainActor in
                try await task()
            }
            addTask(task, cancelID: cancelID)
            let value = try await task.value
            tasksByID[cancelID] = nil
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

    func cancelTask(cancelID: String) {
        if let previousTask = tasksByID[cancelID] {
            previousTask.cancel()
            tasksByID[cancelID] = nil
        }
    }

    func addTask(_ task: CancellableTask, cancelID: String) {
        tasksByID[cancelID] = task
    }

    @discardableResult
    func addTask(_ handle: @escaping () async -> Void) -> CancellableTask {
        let task = Task { @MainActor in
            await handle()
        }
        tasks.append(task)
        return task
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

protocol CancellableTask {
    func cancel()
}

extension Task: CancellableTask {}

enum ScopedState<Parent, Child> {
    case initial(Child)
    case binding(Binding<Child>)
    case keyPath(WritableKeyPath<Parent, Child>)
    case optionalKeyPath(WritableKeyPath<Parent, Child?>, fallback: Child)
}

enum ScopedOutput<Parent: ComponentModel, Child: ComponentModel> {
    case output((Child.Output) -> Parent.Output)
    case input((Child.Output) -> Parent.Input)
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

    func connectTo<Child: ComponentModel>(_ store: ComponentStore<Child>, output handleOutput: @escaping (Child.Output, Event) -> Void) -> ComponentStore<Child> {
        store.events.sink { [weak self] event in
            guard let self else { return }
            self.events.send(event)
        }
        .store(in: &store.subscriptions)

        return store.onOutput { output, event in
            handleOutput(output, event)
        }
    }

    func connectTo<Child: ComponentModel>(_ store: ComponentStore<Child>) -> ComponentStore<Child> where Child.Output == Never {
        store.events.sink { [weak self] event in
            guard let self else { return }
            self.events.send(event)
        }
        .store(in: &store.subscriptions)

        return store
    }

    func scopedStore<Child: ComponentModel>(state: ScopedState<Model.State, Child.State>, route: Child.Route? = nil) -> ComponentStore<Child> {
        let stateStorage: ComponentStore<Child>.StateStorage
        switch state {
        case .initial(let child):
            stateStorage = .root(child)
        case .binding(let binding):
            stateStorage = .binding(binding)
        case .keyPath(let keyPath):
            stateStorage = .binding(keyPathBinding(keyPath))
        case .optionalKeyPath(let keyPath, let fallback):
            stateStorage = .binding(optionalBinding(state: keyPath, value: fallback))
        }
        return ComponentStore<Child>(state: stateStorage, path: self.path, graph: graph, route: route)
    }

    func scope<Child: ComponentModel>(state: ScopedState<Model.State, Child.State>, route: Child.Route? = nil, output scopedOutput: ScopedOutput<Model, Child>) -> ComponentStore<Child> {
        connectTo(scopedStore(state: state, route: route)) { [weak self] output, event in
            guard let self else { return }
            switch scopedOutput{
            case .input(let toInput):
                let input = toInput(output)
                self.processInput(input, source: event.source)
            case .output(let toOutput):
                let output = toOutput(output)
                self.output(output, source: event.source)
            }
        }
    }

    func scope<Child: ComponentModel>(state: ScopedState<Model.State, Child.State>, route: Child.Route? = nil) -> ComponentStore<Child> where Child.Output == Never {
        connectTo(scopedStore(state: state, route: route))
    }
}
