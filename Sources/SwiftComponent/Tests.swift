import Foundation
import CustomDump
import Dependencies

public struct Test<Model: ComponentModel> {

    //TODO: make state named
    public init(_ name: String, _ state: Model.State, appear: Bool = false, assertions: Set<TestAssertion> = .normal, file: StaticString = #file, line: UInt = #line, @TestStepBuilder _ steps: () -> [TestStep<Model>]) {
        self.name = name
        self.state = state
        self.appear = appear
        self.assertions = assertions
        self.source = .capture(file: file, line: line)
        self.steps = steps()
    }

    public init(_ name: String, stateName: String, appear: Bool = false, assertions: Set<TestAssertion> = .normal, file: StaticString = #file, line: UInt = #line, @TestStepBuilder _ steps: () -> [TestStep<Model>]) {
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
    public let assertions: Set<TestAssertion>
}

public enum TestAssertion: String, CaseIterable {
    case output
    case task
    case route
    case mutation
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
    var expectations: [Expectation] = []
    var run: (inout TestContext<Model>) async -> Void

    public init(title: String, details: String? = nil, source: Source, expectations: [TestStep<Model>.Expectation] = [], run: @escaping (inout TestContext<Model>) async -> Void) {
        self.title = title
        self.details = details
        self.source = source
        self.expectations = expectations
        self.run = run
    }

    public var description: String {
        var string = title
        if let details {
            string += ": \(details)"
        }
        return string
    }

    public enum Expectation {
        case validateState(name: String, validateState: (Model.State) -> Bool)
        case validateEmptyRoute
        case validateDependency(error: String, dependency: String, validateDependency: (DependencyValues) -> Bool)
        case expectRoute(Model.Route)
        case expectState((inout Model.State) -> Void)
        case expectOutput(Model.Output)
        case expectTask(String, successful: Bool = true)
    }
}

extension TestStep {
    public static func appear(file: StaticString = #file, line: UInt = #line) -> Self {
        .init(title: "Appear", source: .capture(file: file, line: line)) { context in
            await context.viewModel.appear(first: true)
        }
    }

    public static func input(_ input: Model.Input, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(title: "Input", details: getEnumCase(input).name, source: .capture(file: file, line: line)) { context in
            if context.delay > 0 {
                try? await Task.sleep(nanoseconds: context.delayNanoseconds)
            }
            await context.viewModel.processInput(input, source: context.source, sendEvents: true)
        }
    }

    public static func setBinding<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, _ value: Value, animated: Bool = true, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(title: "Binding", details: "\(keyPath.propertyName ?? "value") = \(value)", source: .capture(file: file, line: line)) { context in
            if animated, let string = value as? String, string.count > 1, string != "", context.delay > 0 {
                let sleepTime = Double(context.delayNanoseconds)/(Double(string.count))
                var currentString = ""
                for character in string {
                    currentString.append(character)
                    context.viewModel.state[keyPath: keyPath] = currentString as! Value
                    if sleepTime > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(sleepTime))
                    }
                }
            } else {
                if context.delay > 0 {
                    try? await Task.sleep(nanoseconds: context.delayNanoseconds)
                }
                context.viewModel.state[keyPath: keyPath] = value
            }
        }
    }

    public static func setDependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, _ dependency: T, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(title: "Set Dependency", details: "\(String(describing: Swift.type(of: dependency)))", source: .capture(file: file, line: line)) { context in
            context.dependencies[keyPath: keyPath] = dependency
        }
    }
}

public struct TestContext<Model: ComponentModel> {
    public let viewModel: ViewModel<Model>
    public let source: Source
    public var dependencies: DependencyValues
    public var delay: TimeInterval

    var delayNanoseconds: UInt64 { UInt64(1_000_000_000.0 * delay) }
}


//public struct TestExpectation<Model: ComponentModel> {
//
//    let name: String
//    let run: (Context) -> [TestError]
//    let source: Source
//
//    struct Context {
//        let viewModel: ViewModel<Model>
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

    public func validateEmptyRoute(file: StaticString = #file, line: UInt = #line) -> Self {
        addExpectation(.validateEmptyRoute, source: .capture(file: file, line: line))
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

    public func expectTask(_ name: String, successful: Bool = true, file: StaticString = #file, line: UInt = #line) -> Self {
        addExpectation(.expectTask(name, successful: successful), source: .capture(file: file, line: line))
    }

    //TODO: also clear mutation assertions
    public func expectResourceTask<R>(_ keyPath: KeyPath<Model.State, Resource<R>>, successful: Bool = true, file: StaticString = #file, line: UInt = #line) -> Self {
        addExpectation(.expectTask(getResourceTaskName(keyPath), successful: successful), source: .capture(file: file, line: line))
    }

    public func expectRoute(_ route: Model.Route, file: StaticString = #file, line: UInt = #line) -> Self {
        addExpectation(.expectRoute(route), source: .capture(file: file, line: line))
    }

}

extension TestStep.Expectation {

    public var title: String {
        switch self {
            case .validateState:
                return "Validate State"
            case .validateEmptyRoute:
                return "Validate empty Route"
            case .expectState:
                return "Expect State"
            case .expectOutput:
                return "Expect Output"
            case .validateDependency:
                return "Validate Dependency"
            case .expectTask:
                return "Expect Task"
            case .expectRoute:
                return "Expect Route"
        }
    }

    public var description: String {
        var string = title
        if let details {
            string += ": \(details)"
        }
        return string
    }

    public var details: String? {
        switch self {
            case .validateState(let name, _ ):
                return "\(name)"
            case .expectState(_):
                return nil
            case .expectOutput(let output):
                return "\(getEnumCase(output).name)"
            case .validateDependency(_, let path, _ ):
                return "\(path)"
            case .validateEmptyRoute:
                return nil
            case .expectRoute(let route):
                return getEnumCase(route).name
            case .expectTask(let name, let success):
                return "\(name) \(success ? "success" : "failure")"
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

public struct TestStepResult<Model: ComponentModel>: Identifiable {
    public var id: UUID { step.id }
    public var step: TestStep<Model>
    public var events: [ComponentEvent]
    public var errors: [TestError]
    public var success: Bool { errors.isEmpty }
}

public struct TestResult<C: ComponentModel> {
    public let steps: [TestStepResult<C>]
    public var success: Bool { errors.isEmpty && steps.allSatisfy(\.success) }
    public var stepErrors: [TestError] { steps.reduce([]) { $0 + $1.errors } }
    public var errors: [TestError] { stepErrors }
}

extension ViewModel {

    @MainActor
    public func runTest(_ test: Test<Model>, initialState: Model.State, assertions: Set<TestAssertion>? = nil, delay: TimeInterval = 0, sendEvents: Bool = false, stepComplete: ((TestStepResult<Model>) -> Void)? = nil) async -> TestResult<Model> {

        // setup dependencies
        var testDependencyValues = DependencyValues._current
        testDependencyValues.context = .preview

        // handle events
//        var events: [ComponentEvent] = []
//        let eventsSubscription = self.events.sink { event in
//            events.append(event)
//        }

        let sendEventsValue = self.sendGlobalEvents
        self.sendGlobalEvents = sendEvents
        defer {
            self.sendGlobalEvents = sendEventsValue
        }

        if delay > 0 {
            self.previewTaskDelay = delay
        }
        defer {
            self.previewTaskDelay = 0
        }

        let assertions = Array(assertions ?? test.assertions).sorted { $0.rawValue < $1.rawValue }

        // setup state
        state = initialState

        // run task
        if test.appear {
            await appear(first: true)
        }

        var stepResults: [TestStepResult<Model>] = []
        let sleepDelay = 1_000_000_000.0 * delay

        for step in test.steps {
            var stepEvents: [ComponentEvent] = []
            let stepEventsSubscription = self.events.sink { event in
                stepEvents.append(event)
            }
            var context = TestContext<Model>(viewModel: self, source: step.source, dependencies: testDependencyValues, delay: delay)
            await withDependencies { dependencyValues in
                dependencyValues = testDependencyValues
            } operation: {
                await step.run(&context)
            }
            testDependencyValues = context.dependencies

            var stepErrors: [TestError] = []

            func findEventValue<T>(_ find: (ComponentEvent) -> T?) -> T? {
                for (index, event) in stepEvents.enumerated() {
                    if let eventValue = find(event) {
                        stepEvents.remove(at: index)
                        return eventValue
                    }
                }
                return nil
            }

            for expectation in step.expectations {
                switch expectation {
                    case .validateState(let name, let validateState):
                        let valid = validateState(state)
                        if !valid {
                            stepErrors.append(TestError(error: "Invalid State \(name.quoted)", source: step.source))
                        }
                    case .validateDependency(let error, let dependency, let validateDependency):
                        let valid = validateDependency(testDependencyValues)
                        if !valid {
                            stepErrors.append(TestError(error: "Invalid \(dependency): \(error)", source: step.source))
                        }
                    case .validateEmptyRoute:
                        if let route = self.route {
                            stepErrors.append(TestError(error: "Unexpected Route \(getEnumCase(route).name.quoted)", source: step.source))
                        }
                    case .expectState(let modify):
                        let currentState = state
                        var expectedState = state
                        modify(&expectedState)
                        if let difference = diff(expectedState, currentState) {
                            stepErrors.append(TestError(error: "Unexpected State", diff: difference, source: step.source))
                        }
                    case .expectRoute(let route):
                        if sleepDelay > 0 {
                            try? await Task.sleep(nanoseconds: UInt64(sleepDelay))
                            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 * 0.35)) // wait for typical presentation animation duration
                        }
                        let foundRoute: Model.Route? = findEventValue { event in
                            if case .route(let route) = event.type, let route = route as? Model.Route {
                                return route
                            }
                            return nil
                        }
                        if let foundRoute {
                            if let difference = diff(foundRoute, route) {
                                stepErrors.append(TestError(error: "Unexpected route value \(getEnumCase(foundRoute).name.quoted)", diff: difference, source: step.source))
                            }
                        } else {
                            stepErrors.append(TestError(error: "Route \(getEnumCase(route).name.quoted) was not sent", source: step.source))
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
                                stepErrors.append(TestError(error: "Unexpected output value \(getEnumCase(foundOutput).name.quoted)", diff: difference, source: step.source))
                            }
                        } else {
                            stepErrors.append(TestError(error: "Output \(getEnumCase(output).name.quoted) was not sent", source: step.source))
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
                                        stepErrors.append(TestError(error: "Expected \(name.quoted) task to succeed, but it failed", source: step.source))
                                    }
                                case .success:
                                    if !successful {
                                        stepErrors.append(TestError(error: "Expected \(name.quoted) task to fail, but it succeeded", source: step.source))
                                    }
                            }
                        } else {
                            stepErrors.append(TestError(error: "Task \(name.quoted) was not sent", source: step.source))
                        }
                }
            }
            for assertion in assertions {
                switch assertion {
                    case .output:
                        for event in stepEvents {
                            switch event.type {
                                case .output(let output):
                                    stepErrors.append(TestError(error: "Output \(getEnumCase(output).name.quoted) was not expected", source: step.source))
                                default: break
                            }
                        }
                    case .task:
                        for event in stepEvents {
                            switch event.type {
                                case .task(let result):
                                    stepErrors.append(TestError(error: "Task \(result.name.quoted) was not expected", source: step.source))
                                default: break
                            }
                        }
                    case .route:
                        for event in stepEvents {
                            switch event.type {
                                case .route(let route):
                                    stepErrors.append(TestError(error: "Route \(getEnumCase(route).name.quoted) was not expected", source: step.source))
                                default: break
                            }
                        }
                    case .mutation:
                        for event in stepEvents {
                            switch event.type {
                                case .mutation(let mutation):
                                    stepErrors.append(TestError(error: "Mutation of \(mutation.property.quoted) was not expected", source: step.source))
                                default: break
                            }
                        }
                }
            }
            let result = TestStepResult(step: step, events: stepEvents, errors: stepErrors)
            stepComplete?(result)
            stepResults.append(result)
        }
        return TestResult(steps: stepResults)
    }
}

#if DEBUG
extension ComponentFeature {

    public static func run(_ test: Test<Model>, assertions: Set<TestAssertion>? = nil) async -> TestResult<Model> {
        guard let state = Self.state(for: test) else {
            fatalError("Could not find state")
        }

        let viewModel = ViewModel<Model>(state: state)
        return await viewModel.runTest(test, initialState: state, assertions: assertions)
    }
}
#endif
