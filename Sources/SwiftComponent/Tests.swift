import Foundation
import CustomDump
import Dependencies
import CasePaths

public struct Test<Model: ComponentModel> {

    public init(_ name: String, state: Model.State, appear: Bool = false, assertions: Set<TestAssertion>? = nil, file: StaticString = #file, line: UInt = #line, @TestStepBuilder _ steps: () -> [TestStep<Model>]) {
        self.name = name
        self.state = state
        self.appear = appear
        self.assertions = assertions
        self.source = .capture(file: file, line: line)
        self.steps = steps()
    }

    public init(_ name: String, stateName: String, appear: Bool = false, assertions: Set<TestAssertion>? = nil, file: StaticString = #file, line: UInt = #line, @TestStepBuilder _ steps: () -> [TestStep<Model>]) {
        self.name = name
        self.stateName = stateName
        self.appear = appear
        self.assertions = assertions
        self.source = .capture(file: file, line: line)
        self.steps = steps()
    }

    public var name: String
    public var state: Model.State?
    public var stateName: String?
    public var steps: [TestStep<Model>]
    public var appear: Bool
    public let source: Source
    public let assertions: Set<TestAssertion>?
}

public enum TestAssertion: String, CaseIterable {
    case output
    case task
    case route
    case mutation
    case dependency
}

extension Set where Element == TestAssertion {
    public static var all: Self { Self(TestAssertion.allCases) }
    public static var none: Self { Self([]) }
    public static var normal: Self { Self([
        .output,
        .task,
        .route,
    ]) }
}

public struct TestStep<Model: ComponentModel>: Identifiable {

    public var title: String
    public var details: String?
    public var source: Source
    public let id = UUID()
    public var expectations: [Expectation] = []
    private var _run: (inout TestContext<Model>) async -> Void

    public init(title: String, details: String? = nil, file: StaticString = #file, line: UInt = #line, run: @escaping @MainActor (inout TestContext<Model>) async -> Void) {
        self.init(title: title, details: details, source: .capture(file: file, line: line), run: run)
    }

    init(title: String, details: String? = nil, source: Source, run: @escaping @MainActor (inout TestContext<Model>) async -> Void) {
        self.title = title
        self.details = details
        self.source = source
        self._run = run
    }

    @MainActor
    public func run(_ context: inout TestContext<Model>) async {
        await _run(&context)
    }

    public var description: String {
        var string = title
        if let details {
            string += ".\(details)"
        }
        return string
    }

    public enum Expectation {
        case validateState(name: String, validateState: (Model.State) -> Bool)
        case validateDependency(error: String, dependency: String, validateDependency: (DependencyValues) -> Bool)
        case expectRoute((Model.Route) -> Any?)
        case expectEmptyRoute
        case expectState((inout Model.State) -> Void)
        case expectOutput(Model.Output)
        case expectTask(String, successful: Bool = true)
    }
}

extension TestStep {

    public static func run(_ title: String, file: StaticString = #file, line: UInt = #line, _ run: @escaping () async -> Void) -> Self {
        .init(title: title, source: .capture(file: file, line: line)) { _ in
            await run()
        }
    }
    public static func appear(first: Bool = true, await: Bool = true, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(title: "Appear", source: .capture(file: file, line: line)) { context in
            if `await` {
                await context.model.appear(first: first)
            } else {
                Task { [context] in
                    await context.model.appear(first: first)
                }
            }
        }
    }

    public static func action(_ action: Model.Action, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(title: "Action", details: getEnumCase(action).name, source: .capture(file: file, line: line)) { context in
            if context.delay > 0 {
                try? await Task.sleep(nanoseconds: context.delayNanoseconds)
            }
            await context.model.store.processAction(action, source: .capture(file: file, line: line))
        }
    }

    public static func input(_ input: Model.Input, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(title: "Input", details: getEnumCase(input).name, source: .capture(file: file, line: line)) { context in
            await context.model.store.processInput(input, source: .capture(file: file, line: line))
        }
    }

    public static func binding<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, _ value: Value, animated: Bool = true, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(title: "Binding", details: "\(keyPath.propertyName ?? "value") = \(value)", source: .capture(file: file, line: line)) { context in
            if animated, let string = value as? String, string.count > 1, string != "", context.delay > 0 {
                let sleepTime = Double(context.delayNanoseconds)/(Double(string.count))
                var currentString = ""
                for character in string {
                    currentString.append(character)
                    context.model.store.mutate(keyPath, value: currentString as! Value, source: .capture(file: file, line: line))
                    if sleepTime > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(sleepTime))
                    }
                }
            } else {
                if context.delay > 0 {
                    try? await Task.sleep(nanoseconds: context.delayNanoseconds)
                }
                context.model.store.mutate(keyPath, value: value, source: .capture(file: file, line: line))
            }
        }
    }

    public static func dependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, _ dependency: T, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(title: "Dependency", details: "\(String(describing: Swift.type(of: dependency)))", source: .capture(file: file, line: line)) { context in
            context.dependencies[keyPath: keyPath] = dependency
        }
    }

    public static func route<Child: ComponentModel>(_ path: CasePath<Model.Route, ComponentRoute<Child>>, file: StaticString = #file, line: UInt = #line, @TestStepBuilder _ steps: @escaping () -> [TestStep<Child>]) -> Self {
        .init(title: "Route", details: Child.baseName, source: .capture(file: file, line: line)) { context in
            guard let route = context.model.store.route else { return }
            guard let componentRoute = path.extract(from: route) else { return }

            if context.delay > 0 {
                try? await Task.sleep(nanoseconds: context.delayNanoseconds)
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 * 0.35)) // wait for typical presentation animation duration
            }

            let steps = steps()
            var childContext = TestContext<Child>(model: componentRoute.viewModel, dependencies: context.dependencies, delay: context.delay, assertions: context.assertions)
            for step in steps {
                let results = await step.runTest(context: &childContext)
                context.childStepResults.append(results)
            }
        }
    }

    public static func scope<Child: ComponentModel>(_ model: Child.Type, file: StaticString = #file, line: UInt = #line, scope: @escaping (ViewModel<Model>) -> ViewModel<Child>, @TestStepBuilder steps: @escaping () -> [TestStep<Child>]) -> Self {
        .init(title: "Scope", details: Child.baseName, source: .capture(file: file, line: line)) { context in
            let viewModel = scope(context.model)
            let steps = steps()
            var childContext = TestContext<Child>(model: viewModel, dependencies: context.dependencies, delay: context.delay, assertions: context.assertions)
            for step in steps {
                let results = await step.runTest(context: &childContext)
                context.childStepResults.append(results)
            }
        }
    }

    public static func scope<Child: ComponentModel>(_ connection: ComponentConnection<Model, Child>, file: StaticString = #file, line: UInt = #line, @TestStepBuilder steps: @escaping () -> [TestStep<Child>]) -> Self {
        .init(title: "Scope", details: Child.baseName, source: .capture(file: file, line: line)) { context in
            let viewModel = connection.convert(context.model)
            let steps = steps()
            var childContext = TestContext<Child>(model: viewModel, dependencies: context.dependencies, delay: context.delay, assertions: context.assertions)
            for step in steps {
                let results = await step.runTest(context: &childContext)
                context.childStepResults.append(results)
            }
        }
    }
}

public struct TestContext<Model: ComponentModel> {
    public let model: ViewModel<Model>
    public var dependencies: DependencyValues
    public var delay: TimeInterval
    public var assertions: [TestAssertion]
    public var childStepResults: [TestStepResult] = []

    var delayNanoseconds: UInt64 { UInt64(1_000_000_000.0 * delay) }
}

//public struct TestExpectation<Model: ComponentModel> {
//
//    let name: String
//    let run: (Context) -> [TestError]
//    let source: Source
//
//    struct Context {
//        let store: ViewModel<Model>
//        let dependencies: DependencyValues
//        let events: [ComponentEvent]
//    }
//}
//
//extension TestStep {
//
//    func expect(_ expectation: Expectation) {
//
//    }
//}

extension TestStep {

    func addExpectation(_ expectation: Expectation, source: Source) -> Self {
        var step = self
        step.expectations.append(expectation)
        return step
    }

    public func validateDependency<T>(_ error: String, _ keyPath: KeyPath<DependencyValues, T>, _ validateDependency: @escaping (T) -> Bool, file: StaticString = #file, line: UInt = #line) -> Self {
        addExpectation(.validateDependency(error: error, dependency: String(describing: T.self), validateDependency: { validateDependency($0[keyPath: keyPath]) }), source: .capture(file: file, line: line))
    }

    public func expectOutput(_ output: Model.Output, file: StaticString = #file, line: UInt = #line) -> Self {
        addExpectation(.expectOutput(output), source: .capture(file: file, line: line))
    }

    /// validate some properties on state by returning a boolean
    public func validateState(_ name: String, file: StaticString = #file, line: UInt = #line, _ validateState: @escaping (Model.State) -> Bool) -> Self {
        addExpectation(.validateState(name: name, validateState: validateState), source: .capture(file: file, line: line))
    }

    /// expect state to have certain properties set. Set any properties on the state that should be set. Any properties left out fill not fail the test
    public func expectState(file: StaticString = #file, line: UInt = #line, _ modify: @escaping (inout Model.State) -> Void) -> Self {
        addExpectation(.expectState(modify), source: .capture(file: file, line: line))
    }

    /// expect state to have a keypath set to a value
    public func expectState<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, _ value: Value, file: StaticString = #file, line: UInt = #line) -> Self {
        addExpectation(.expectState { $0[keyPath: keyPath] = value }, source: .capture(file: file, line: line))
    }

    public func expectTask(_ taskID: Model.Task, successful: Bool = true, file: StaticString = #file, line: UInt = #line) -> Self {
        addExpectation(.expectTask(taskID.taskName, successful: successful), source: .capture(file: file, line: line))
    }

    //TODO: also clear mutation assertions
    public func expectResourceTask<R>(_ keyPath: KeyPath<Model.State, Resource<R>>, successful: Bool = true, file: StaticString = #file, line: UInt = #line) -> Self {
        addExpectation(.expectTask(getResourceTaskName(keyPath), successful: successful), source: .capture(file: file, line: line))
    }

    public func expectEmptyRoute(file: StaticString = #file, line: UInt = #line) -> Self {
        addExpectation(.expectEmptyRoute, source: .capture(file: file, line: line))
    }

    public func expectRoute<Child: ComponentModel>(_ path: CasePath<Model.Route, ComponentRoute<Child>>, state: Child.State, childRoute: Child.Route? = nil, file: StaticString = #file, line: UInt = #line) -> Self {
        let componentRoute = ComponentRoute<Child>(state: state, route: childRoute)
        componentRoute.store = .init(state: state)
        return addExpectation(.expectRoute { route in
            path.extract(from: route)?.state
        }, source: .capture(file: file, line: line))
    }

}

extension TestStep.Expectation {

    public var title: String {
        switch self {
            case .validateState:
                return "Validate"
            case .expectState:
                return "Expect state"
            case .expectOutput:
                return "Expect output"
            case .validateDependency:
                return "Validate dependency"
            case .expectTask:
                return "Expect task"
            case .expectRoute:
                return "Expect route"
            case .expectEmptyRoute:
                return "Expect empty route"
        }
    }

    public var description: String {
        var string = title
        if let details {
            string += " \(details)"
        }
        return string
    }

    public var details: String? {
        switch self {
            case .validateState(let name, _ ):
                return name.quoted
            case .expectState(_):
                return nil
            case .expectOutput(let output):
                return getEnumCase(output).name.quoted
            case .validateDependency(_, let path, _ ):
                return path.quoted
            case .expectRoute(let route):
                return getEnumCase(route).name.quoted
            case .expectEmptyRoute:
                return nil
            case .expectTask(let name, let success):
                return "\(name.quoted) \(success ? "success" : "failure")"
        }
    }
}

@resultBuilder
public struct TestBuilder {
    public static func buildBlock<ComponentType: ComponentModel>() -> [Test<ComponentType>] { [] }
    public static func buildBlock<ComponentType: ComponentModel>(_ tests: Test<ComponentType>...) -> [Test<ComponentType>] { tests }
    public static func buildBlock<ComponentType: ComponentModel>(_ tests: [Test<ComponentType>]) -> [Test<ComponentType>] { tests }
}

@resultBuilder
public struct TestStepBuilder {
    public static func buildBlock<Model: ComponentModel>() -> [TestStep<Model>] { [] }
    public static func buildBlock<Model: ComponentModel>(_ tests: TestStep<Model>...) -> [TestStep<Model>] { tests }
    public static func buildBlock<Model: ComponentModel>(_ tests: [TestStep<Model>]) -> [TestStep<Model>] { tests }
}

public struct TestError: CustomStringConvertible, Identifiable, Hashable {
    public var error: String
    public var diff: String?
    public let source: Source
    public let id = UUID()

    public var description: String {
        var string = error
        if let diff {
            string += ":\n\(diff)"
        }
        return string
    }
}

public struct TestStepResult: Identifiable {

    public var id: UUID
    public var title: String
    public var details: String?
    public var expectations: [String]
    public var events: [Event]
    public var errors: [TestError]
    public var allErrors: [TestError] {
        errors + childResults.reduce([]) { $0 + $1.errors }
    }
    public var childResults: [TestStepResult]
    public var success: Bool { allErrors.isEmpty }

    init<Model>(step: TestStep<Model>, events: [Event], errors: [TestError], childResults: [TestStepResult]) {
        self.id = step.id
        self.title = step.title
        self.details = step.details
        self.expectations = step.expectations.map(\.description)
        self.events = events
        self.errors = errors
        self.childResults = childResults
    }

    public var description: String {
        var string = title
        if let details {
            string += ".\(details)"
        }
        return string
    }
}

public struct TestResult<Model: ComponentModel> {
    public let steps: [TestStepResult]
    public var success: Bool { errors.isEmpty && steps.allSatisfy(\.success) }
    public var stepErrors: [TestError] { steps.reduce([]) { $0 + $1.errors } }
    public var errors: [TestError] { stepErrors }
}

extension ViewModel {

    @MainActor
    public func runTest(_ test: Test<Model>, initialState: Model.State, assertions: Set<TestAssertion>, delay: TimeInterval = 0, sendEvents: Bool = false, stepComplete: ((TestStepResult) -> Void)? = nil) async -> TestResult<Model> {

        let assertions = Array(test.assertions ?? assertions).sorted { $0.rawValue < $1.rawValue }

        // setup dependencies
        var testDependencyValues = DependencyValues._current
        // rely on Dependencies failing when in test context
        if assertions.contains(.dependency) {
            testDependencyValues.context = .test
        } else {
            testDependencyValues.context = .preview
        }

        // handle events
//        var events: [ComponentEvent] = []
//        let eventsSubscription = self.events.sink { event in
//            events.append(event)
//        }

        let sendEventsValue = store.sendGlobalEvents
        store.sendGlobalEvents = sendEvents
        defer {
            store.sendGlobalEvents = sendEventsValue
        }

        if delay > 0 {
            store.previewTaskDelay = delay
        }
        defer {
            store.previewTaskDelay = 0
        }

        state = initialState

        if test.appear {
            await appear(first: true)
        }

        var stepResults: [TestStepResult] = []
        var context = TestContext<Model>(model: self, dependencies: testDependencyValues, delay: delay, assertions: assertions)
        for step in test.steps {
            let result = await step.runTest(context: &context)
            stepComplete?(result)
            stepResults.append(result)
        }
        return TestResult(steps: stepResults)
    }
}

extension TestStep {

    @MainActor
    func runTest(context: inout TestContext<Model>) async -> TestStepResult {
        var stepEvents: [Event] = []
        let path = context.model.store.path
        let stepEventsSubscription = context.model.store.events.sink { event in
            if event.componentPath == path {
                stepEvents.append(event)
            }
        }
        await withDependencies { dependencyValues in
            dependencyValues = context.dependencies
        } operation: { @MainActor in
            await self.run(&context)
        }

        var stepErrors: [TestError] = []

        func findEventValue<T>(_ find: (Event) -> T?) -> T? {
            for (index, event) in stepEvents.enumerated() {
                if let eventValue = find(event) {
                    stepEvents.remove(at: index)
                    return eventValue
                }
            }
            return nil
        }

        let state = context.model.state
        let source = self.source
        for expectation in self.expectations {
            switch expectation {
                case .validateState(let name, let validateState):
                    let valid = validateState(state)
                    if !valid {
                        stepErrors.append(TestError(error: "Invalid State \(name.quoted)", source: source))
                    }
                case .validateDependency(let error, let dependency, let validateDependency):
                    let valid = validateDependency(context.dependencies)
                    if !valid {
                        stepErrors.append(TestError(error: "Invalid \(dependency): \(error)", source: source))
                    }
                case .expectState(let modify):
                    let currentState = state
                    var expectedState = state
                    modify(&expectedState)
                    if let difference = diff(expectedState, currentState) {
                        stepErrors.append(TestError(error: "Unexpected State", diff: difference, source: source))
                    }
                case .expectRoute(let getRoute):
                    let foundRoute: Model.Route? = findEventValue { event in
                        if case .route(let route) = event.type, let route = route as? Model.Route {
                            return route
                        }
                        return nil
                    }
                    if let foundRoute {
                        if let route = context.model.route {
                            let foundState = getRoute(foundRoute)
                            let currentState = getRoute(route)
                            if let difference = diff(foundState, currentState) {
                                stepErrors.append(TestError(error: "Unexpected route value \(getEnumCase(foundRoute).name.quoted)", diff: difference, source: source))
                            }
                            // TODO: compare nested route
                        } else {
                            stepErrors.append(TestError(error: "Unexpected empty route", source: source))
                        }

                    } else {
                        stepErrors.append(TestError(error: "Route \(getEnumCase(context.model.route).name.quoted) was not sent", source: source))
                    }
                case .expectEmptyRoute:
                    if let route = context.model.route {
                        stepErrors.append(TestError(error: "Unexpected Route \(getEnumCase(route).name.quoted)", source: source))
                    }
                case .expectOutput(let output):
                    let foundOutput: Model.Output? = findEventValue { event in
                        if case .output(let output) = event.type, let output = output as? Model.Output {
                            return output
                        }
                        return nil
                    }
                    if let foundOutput {
                        if let difference = diff(foundOutput, output) {
                            stepErrors.append(TestError(error: "Unexpected output value \(getEnumCase(foundOutput).name.quoted)", diff: difference, source: source))
                        }
                    } else {
                        stepErrors.append(TestError(error: "Output \(getEnumCase(output).name.quoted) was not sent", source: source))
                    }
                case .expectTask(let name, let successful):
                    let result: TaskResult? = findEventValue { event in
                        if case .task(let taskResult) = event.type {
                            return taskResult
                        }
                        return nil
                    }
                    if let result {
                        switch result.result {
                            case .failure:
                                if successful {
                                    stepErrors.append(TestError(error: "Expected \(name.quoted) task to succeed, but it failed", source: source))
                                }
                            case .success:
                                if !successful {
                                    stepErrors.append(TestError(error: "Expected \(name.quoted) task to fail, but it succeeded", source: source))
                                }
                        }
                    } else {
                        stepErrors.append(TestError(error: "Task \(name.quoted) was not sent", source: source))
                    }
            }
        }
        for assertion in context.assertions {
            switch assertion {
                case .output:
                    for event in stepEvents {
                        switch event.type {
                            case .output(let output):
                                stepErrors.append(TestError(error: "Unexpected output \(getEnumCase(output).name.quoted)", source: source))
                            default: break
                        }
                    }
                case .task:
                    for event in stepEvents {
                        switch event.type {
                            case .task(let result):
                                stepErrors.append(TestError(error: "Unexpected task \(result.name.quoted)", source: source))
                            default: break
                        }
                    }
                case .route:
                    for event in stepEvents {
                        switch event.type {
                            case .route(let route):
                                stepErrors.append(TestError(error: "Unexpected route \(getEnumCase(route).name.quoted)", source: source))
                            default: break
                        }
                    }
                case .mutation:
                    for event in stepEvents {
                        switch event.type {
                            case .mutation(let mutation):
                                stepErrors.append(TestError(error: "Unexpected mutation of \(mutation.property.quoted)", source: source))
                            default: break
                        }
                    }
                case .dependency: break
            }
        }
        return TestStepResult(step: self, events: stepEvents, errors: stepErrors, childResults: context.childStepResults)
    }
}

#if DEBUG
extension Component {

    public static func run(_ test: Test<Model>, assertions: Set<TestAssertion>? = nil) async -> TestResult<Model> {
        guard let state = Self.state(for: test) else {
            fatalError("Could not find state")
        }

        let model = ViewModel<Model>(state: state)
        return await model.runTest(test, initialState: state, assertions: assertions ?? testAssertions)
    }
}
#endif
