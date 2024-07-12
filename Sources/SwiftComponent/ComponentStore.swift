import Foundation
import SwiftUI
import Combine
import os
import Dependencies

class ComponentStore<Model: ComponentModel> {
    
    enum StateStorage {
        case root(Model.State)
        case binding(StateBinding<Model.State>)
        
        var state: Model.State {
            get {
                switch self {
                case .root(let state): return state
                case .binding(let binding): return binding.state
                }
            }
            set {
                switch self {
                case .root:
                    self = .root(newValue)
                case .binding(let binding):
                    binding.state = newValue
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
    private var tasks: [UUID: CancellableTask] = [:]
    private var appearanceTask: CancellableTask?
    let stateChanged = PassthroughSubject<Model.State, Never>()
    let routeChanged = PassthroughSubject<Model.Route?, Never>()
    let environmentChanged = PassthroughSubject<Model.Environment, Never>()
    var environment: Model.Environment {
        didSet {
            environmentChanged.send(environment)
        }
    }
    let logger: Logger
    var logEvents: Set<EventSimpleType> = []
    var logChildEvents: Bool = true
    var modelCancellables: Set<AnyCancellable> = []
    
    let _$observationRegistrar = PerceptionRegistrar(
        isPerceptionCheckingEnabled: _isStorePerceptionCheckingEnabled
    )
    
    var state: Model.State {
        get {
            _$observationRegistrar.access(self, keyPath: \.state)
            return stateStorage.state
        }
        set {
            guard !areMaybeEqual(stateStorage.state, newValue) else { return }
            if let old = stateStorage.state as? any ObservableState,
               let new = newValue as? any ObservableState,
               old._$id == new._$id {
                stateStorage.state = newValue
            } else {
                self._$observationRegistrar.withMutation(of: self, keyPath: \.state) {
                    stateStorage.state = newValue
                }
            }
            stateChanged.send(newValue)
        }
    }
    
    let id = UUID()
    var route: Model.Route? {
        didSet {
            routeChanged.send(route)
            if let route = route {
                graph.addRoute(store: self, route: route)
            } else {
                graph.removeRoute(store: self)
            }
        }
    }
    var modelContext: ModelContext<Model>!
    var model: Model!
    var cancellables: Set<AnyCancellable> = []
    private var mutations: [Mutation] = []
    var handledAppear = false
    var handledDisappear = false
    var sendGlobalEvents = true
    var presentationMode: Binding<PresentationMode>?
    private var lastSource: Source? // used to get at the original source of a mutation, due to no source info on dynamic member lookup
    public var events = PassthroughSubject<Event, Never>()
    private var subscriptions: Set<AnyCancellable> = []
    var stateDump: String { dumpToString(state) }
    
    convenience init(state: StateStorage, path: ComponentPath?, graph: ComponentGraph, route: Model.Route? = nil) where Model.Environment == EmptyEnvironment {
        self.init(state: state, path: path, graph: graph, environment: EmptyEnvironment(), route: route)
    }
    
    init(state: StateStorage, path: ComponentPath?, graph: ComponentGraph, environment: Model.Environment, route: Model.Route? = nil) {
        self.stateStorage = state
        
        self.graph = graph
        self.environment = environment
        let path = path?.appending(Model.self) ?? ComponentPath(Model.self)
        self.path = path
        self.dependencies = ComponentDependencies()
        self.logger = Logger(subsystem: "SwiftComponent", category: path.string)
        let modelContext = ModelContext(store: self)
        self.model = Model(context: modelContext)
        self.modelContext = modelContext
        if let route = route {
            model.connect(route: route)
            self.route = route
        }
        events.sink { [weak self] event in
            self?.model.handle(event: event)
        }
        .store(in: &subscriptions)
    }
    
    deinit {
        modelCancellables = []
        cancelTasks()
    }
    
    func cancelTasks() {
        tasksByID.forEach { $0.value.cancel() }
        tasksByID = [:]
        tasks.values.forEach { $0.cancel() }
        tasks = [:]
    }
    
    @MainActor
    private func startEvent() {
        eventsInProgress += 1
    }
    
    @MainActor
    fileprivate func sendEvent(type: EventType, start: Date, mutations: [Mutation], source: Source) {
        eventsInProgress -= 1
        if eventsInProgress < 0 {
            assertionFailure("Parent count is \(eventsInProgress), but should only be 0 or more")
        }
        let event = Event(type: type, storeID: id, componentPath: path, start: start, end: Date(), mutations: mutations, depth: eventsInProgress, source: source)
        events.send(event)
        log(event)
        guard sendGlobalEvents else { return }
        EventStore.shared.send(event)
    }
    
    func log(_ event: Event) {
        if logEvents.contains(event.type.type) {
            let details = event.type.details
            let eventString = "\(event.type.title.lowercased())\(details.isEmpty ? "" : ": ")\(details)"
            //            let relativePath = event.path.relative(to: self.path).string
            //            logger.info("\(relativePath)\(relativePath.isEmpty ? "" : ": ")\(eventString)")
            print("Component \(event.path.string).\(eventString)")
        }
    }
    
    @MainActor
    func processAction(_ action: Model.Action, source: Source) {
        lastSource = source
        addTask { @MainActor in
            await self.processAction(action, source: source)
        }
    }
    
    @MainActor
    func processAction(_ action: Model.Action, source: Source) async {
        let eventStart = Date()
        startEvent()
        mutations = []
        await model.handle(action: action)
        sendEvent(type: .action(action), start: eventStart, mutations: mutations, source: source)
    }
    
    func processInput(_ input: Model.Input, source: Source) {
        lastSource = source
        addTask { @MainActor in
            await self.processInput(input, source: source)
        }
    }
    
    @MainActor
    func processInput(_ input: Model.Input, source: Source) async {
        let eventStart = Date()
        startEvent()
        mutations = []
        await model.handle(input: input)
        sendEvent(type: .input(input), start: eventStart, mutations: mutations, source: source)
    }
    
    func onOutput(_ handle: @MainActor @escaping (Model.Output, Event) -> Void) -> Self {
        self.onEvent { event in
            if case let .output(output) = event.type, let output = output as? Model.Output {
                handle(output, event)
            }
        }
    }
    
    @discardableResult
    func onEvent(_ handle: @MainActor @escaping (Event) -> Void) -> Self {
        self.events
            .sink { event in
                Task { @MainActor in handle(event) }
            }
            .store(in: &cancellables)
        return self
    }
}

// MARK: View Accessors
extension ComponentStore {
    
    @MainActor
    func binding<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, file: StaticString = #filePath, line: UInt = #line) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { value in
                guard self.setBindingValue(keyPath, value, file: file, line: line) else { return }
                
                self.addTask { @MainActor in
                    await self.model.binding(keyPath: keyPath)
                }
            }
        )
    }
    
    /// called from test step
    @MainActor
    func setBinding<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, _ value: Value, file: StaticString = #filePath, line: UInt = #line) async {
        guard self.setBindingValue(keyPath, value, file: file, line: line) else { return }
        await self.model.binding(keyPath: keyPath)
    }
    
    @MainActor
    private func setBindingValue<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, _ value: Value, file: StaticString, line: UInt) -> Bool {
        let start = Date()
        let oldState = self.state
        let oldValue = self.state[keyPath: keyPath]
        // don't continue if change doesn't lead to state change
        guard !areMaybeEqual(oldValue, value) else { return false }
        
        self.startEvent()
        self.state[keyPath: keyPath] = value
        let mutation = Mutation(keyPath: keyPath, value: value, oldState: oldState)
        self.sendEvent(type: .binding(mutation), start: start, mutations: [mutation], source: .capture(file: file, line: line))
        return true
    }
    
}

// MARK: ComponentView Accessors
extension ComponentStore {
    
    @MainActor
    func appear(first: Bool, file: StaticString = #filePath, line: UInt = #line) {
        appearanceTask = addTask { @MainActor in
            await self.appear(first: first, file: file, line: line)
        }
    }
    
    @MainActor
    func appear(first: Bool, file: StaticString = #filePath, line: UInt = #line) async {
        let start = Date()
        startEvent()
        mutations = []
        handledAppear = true
        await model?.appear()
        sendEvent(type: .view(.appear(first: first)), start: start, mutations: self.mutations, source: .capture(file: file, line: line))
    }
    
    @MainActor
    func disappear(file: StaticString = #filePath, line: UInt = #line) {
        addTask { @MainActor in
            let start = Date()
            self.startEvent()
            self.mutations = []
            self.handledDisappear = true
            await self.model.disappear()
            self.sendEvent(type: .view(.disappear), start: start, mutations: self.mutations, source: .capture(file: file, line: line))
            
            self.appearanceTask?.cancel()
            self.appearanceTask = nil
        }
    }
    
    @MainActor
    func bodyAccessed(start: Date, file: StaticString = #filePath, line: UInt = #line) {
        if graph.sendViewBodyEvents {
            startEvent()
            sendEvent(type: .view(.body), start: start, mutations: self.mutations, source: .capture(file: file, line: line))
        }
    }
    
    @MainActor
    func setPresentationMode(_ presentationMode: Binding<PresentationMode>) {
        self.presentationMode = presentationMode
    }
}

// MARK: Model Accessors
extension ComponentStore {
    
    @MainActor
    func mutate<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, value: Value, animation: Animation? = nil, source: Source?) {
        // we can't get the source in dynamic member lookup, so just use the original action or input
        let source = source ?? lastSource ?? .capture()
        let start = Date()
        startEvent()
        
        let oldState = stateStorage.state
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
    
    @MainActor
    func output(_ event: Model.Output, source: Source) {
        startEvent()
        self.sendEvent(type: .output(event), start: Date(), mutations: [], source: source)
    }
    
    @MainActor
    func task<R>(_ name: String, cancellable: Bool, source: Source, _ task: @MainActor @escaping () async throws -> R, catch catchError: (Error) -> Void) async {
        do {
            try await self.task(name, cancellable: cancellable, source: source, task) as R
        } catch {
            catchError(error)
        }
    }
    
    @MainActor
    // TODO: combine with bottom
    func task<R>(_ name: String, cancellable: Bool, source: Source,  _ task: @escaping () async -> R) async -> R {
        let cancelID = name
        
        if previewTaskDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 * previewTaskDelay))
        }
        
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
        sendEvent(type: .task(result), start: start, mutations: mutations, source: source)
        return value
    }
    
    @MainActor
    @discardableResult
    func task<R>(_ name: String, cancellable: Bool, source: Source, _ task: @escaping () async throws -> R) async throws -> R {
        let cancelID = name
        let start = Date()
        startEvent()
        mutations = []
        if previewTaskDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 * previewTaskDelay))
        }
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
            sendEvent(type: .task(TaskResult(name: name, result: .success(value))), start: start, mutations: mutations, source: source)
            return value
        } catch {
            sendEvent(type: .task(TaskResult(name: name, result: .failure(error))), start: start, mutations: mutations, source: source)
            throw error
        }
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
        let taskID = UUID()
        let task = Task { @MainActor in
            await handle()
            tasks[taskID] = nil
        }
        tasks[taskID] = task
        return task
    }
    
    @MainActor
    func present(_ route: Model.Route, source: Source) {
        _ = model.connect(route: route)
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
    case stateBinding(StateBinding<Child>)
    case keyPath(WritableKeyPath<Parent, Child>)
    case optionalKeyPath(WritableKeyPath<Parent, Child?>, fallback: Child)
}

enum ScopedOutput<Parent: ComponentModel, Child: ComponentModel> {
    case output((Child.Output) -> Parent.Output)
    case input((Child.Output) -> Parent.Input)
}

// MARK: Scoping
extension ComponentStore {
    
    private func keyPathBinding<Value>(_ keyPath: WritableKeyPath<Model.State, Value>) -> StateBinding<Value> {
        StateBinding(
            get: { self.stateStorage.state[keyPath: keyPath] },
            set: { self.stateStorage.state[keyPath: keyPath] = $0 }
        )
    }
    
    private func optionalBinding<ChildState>(state stateKeyPath: WritableKeyPath<Model.State, ChildState?>, value: ChildState) -> StateBinding<ChildState> {
        let optionalBinding = keyPathBinding(stateKeyPath)
        return StateBinding<ChildState> {
            optionalBinding.state ?? value
        } set: {
            optionalBinding.state = $0
        }
    }
    
    func optionalCaseBinding<ChildState, Enum: CasePathable>(state stateKeyPath: WritableKeyPath<Model.State, Enum?>, `case`: CaseKeyPath<Enum, ChildState>, value: ChildState) -> StateBinding<ChildState> {
        StateBinding(
            get: { self.stateStorage.state[keyPath: stateKeyPath]?[case: `case`] ?? value },
            set: { self.stateStorage.state[keyPath: stateKeyPath]?[case: `case`] = $0 }
        )
    }
    
    func connectTo<Child: ComponentModel>(_ store: ComponentStore<Child>, output handleOutput: @MainActor @escaping (Child.Output, Event) -> Void) -> ComponentStore<Child> {
        store.events.sink { [weak self] event in
            guard let self else { return }
            self.events.send(event)
            if self.logChildEvents {
                log(event)
            }
        }
        .store(in: &store.subscriptions)
        
        return store.onOutput { @MainActor output, event in
            handleOutput(output, event)
        }
    }
    
    func connectTo<Child: ComponentModel>(_ store: ComponentStore<Child>) -> ComponentStore<Child> where Child.Output == Never {
        store.events.sink { [weak self] event in
            guard let self else { return }
            self.events.send(event)
            if self.logChildEvents {
                log(event)
            }
        }
        .store(in: &store.subscriptions)
        
        return store
    }
    
    func scopedStore<Child: ComponentModel>(state: ScopedState<Model.State, Child.State>, environment: Child.Environment, route: Child.Route?) -> ComponentStore<Child> {
        let stateStorage: ComponentStore<Child>.StateStorage
        switch state {
        case .initial(let child):
            stateStorage = .root(child)
        case .binding(let binding):
            stateStorage = .binding(.init(binding : binding))
        case .keyPath(let keyPath):
            stateStorage = .binding(keyPathBinding(keyPath))
        case .optionalKeyPath(let keyPath, let fallback):
            stateStorage = .binding(optionalBinding(state: keyPath, value: fallback))
        case .stateBinding(let binding):
            stateStorage = .binding(binding)
        }
        let store = ComponentStore<Child>(state: stateStorage, path: self.path, graph: graph, environment: environment, route: route)
        store.dependencies.apply(self.dependencies)
        if route == nil {
            if let existingRoute = graph.getRoute(store: store) {
                store.route = existingRoute
            }
        }
        return store
    }
    
    func scope<Child: ComponentModel>(state: ScopedState<Model.State, Child.State>, route: Child.Route? = nil, output scopedOutput: ScopedOutput<Model, Child>) -> ComponentStore<Child> where Model.Environment == Child.Environment {
        connectTo(scopedStore(state: state, environment: self.environment, route: route)) { [weak self] output, event in
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
    
    func scope<Child: ComponentModel>(state: ScopedState<Model.State, Child.State>, environment: Child.Environment, route: Child.Route? = nil, output scopedOutput: ScopedOutput<Model, Child>) -> ComponentStore<Child> {
        connectTo(scopedStore(state: state, environment: environment, route: route)) { @MainActor [weak self] output, event in
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
    
    func scope<Child: ComponentModel>(state: ScopedState<Model.State, Child.State>, route: Child.Route? = nil) -> ComponentStore<Child> where Child.Output == Never, Model.Environment == Child.Environment {
        connectTo(scopedStore(state: state, environment: self.environment, route: route))
    }
    
    func scope<Child: ComponentModel>(state: ScopedState<Model.State, Child.State>, environment: Child.Environment, route: Child.Route? = nil) -> ComponentStore<Child> where Child.Output == Never {
        connectTo(scopedStore(state: state, environment: environment, route: route))
    }
}

#if canImport(Perception)
private let _isStorePerceptionCheckingEnabled: Bool = {
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
        return false
    } else {
        return true
    }
}()
#endif

#if !os(visionOS)
extension ComponentStore: Perceptible {}
#endif

#if canImport(Observation)
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension ComponentStore: Observable {}
#endif

// Similar to SwiftUI.Binding but simpler and seems to fix issues with scope bindings and presentations
public struct StateBinding<State> {
    let get: () -> State
    let set: (State) -> Void
    
    var state: State {
        get { get() }
        nonmutating set { set(newValue) }
    }
}

extension StateBinding {
    init(binding: Binding<State>) {
        self.init(get: { binding.wrappedValue }, set: { binding.wrappedValue = $0 })
    }
}
