import Foundation
@_implementationOnly import Runtime

public struct TestContext<Model: ComponentModel> {
    public let model: ViewModel<Model>
    public var delay: TimeInterval
    public var assertions: [TestAssertion]
    public var runAssertions: Bool = true
    public var childStepResults: [TestStepResult] = []
    public var stepErrors: [TestError] = []
    var state: Model.State

    var delayNanoseconds: UInt64 { UInt64(1_000_000_000.0 * delay) }
}

extension ViewModel {

    @MainActor
    public func runTest(_ test: Test<Model>, initialState: Model.State, assertions: Set<TestAssertion>, delay: TimeInterval = 0, sendEvents: Bool = false, stepComplete: ((TestStepResult) -> Void)? = nil) async -> TestResult<Model> {
        let start = Date()
        let assertions = Array(test.assertions ?? assertions).sorted { $0.rawValue < $1.rawValue }

        // for now rely on Dependencies failing when in test context
        if assertions.contains(.dependency) {
            self.store.dependencies.dependencyValues.context = .test
        } else {
            self.store.dependencies.dependencyValues.context = .preview
        }

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
        route = nil

        var stepResults: [TestStepResult] = []
        var context = TestContext<Model>(model: self, delay: delay, assertions: assertions, state: initialState)
        for step in test.steps {
            context.stepErrors = []
            var result = await step.runTest(context: &context)
            result.stepErrors.append(contentsOf: context.stepErrors)
            stepComplete?(result)
            stepResults.append(result)
        }
        return TestResult<Model>(start: start, end: Date(), steps: stepResults)
    }
}

extension TestStep {

    @MainActor
    func runTest(context: inout TestContext<Model>) async -> TestStepResult {
        var stepEvents: [Event] = []
        var unexpectedEvents: [Event] = []
        context.state = context.model.state
        context.childStepResults = []
        let runAssertions = context.runAssertions
        let storeID = context.model.store.id
        let stepEventsSubscription = context.model.store.events.sink { event in
            // TODO: should probably check id instead
            if event.storeID == storeID {
                stepEvents.append(event)
                unexpectedEvents.append(event)
            }
        }
        _ = stepEventsSubscription // hide warning
        await withDependencies { dependencyValues in
            dependencyValues = context.model.store.dependencies.dependencyValues
        } operation: { @MainActor in
            await self.run(&context)
        }

        var expectationErrors: [TestError] = []
        for expectation in expectations {
            var expectationContext = TestExpectation<Model>.Context(testContext: context, source: expectation.source, events: unexpectedEvents)
            expectation.run(&expectationContext)
            unexpectedEvents = expectationContext.events
            context.state = expectationContext.testContext.state
            expectationErrors += expectationContext.errors
        }

        var assertionErrors: [TestError] = []
        var assertionWarnings: [TestError] = []
        if context.runAssertions {

            for assertion in context.assertions {
                assertionErrors += assertion.assert(events: unexpectedEvents, context: context, source: source)
            }

            for assertion in TestAssertion.allCases {
                if !context.assertions.contains(assertion) {
                    assertionWarnings += assertion.assert(events: unexpectedEvents, context: context, source: source)
                }
            }
        }

        context.runAssertions = runAssertions

        var testCoverage = TestCoverage()
        do {
            let checkActions = (try? typeInfo(of: Model.Action.self))?.kind == .enum
            let checkOutputs = (try? typeInfo(of: Model.Output.self))?.kind == .enum
            let checkRoutes = (try? typeInfo(of: Model.Route.self))?.kind == .enum

            for event in stepEvents where event.path == context.model.path {
                switch event.type {
                case .action(let action):
                    if checkActions {
                        testCoverage.actions.insert(getEnumCase(action).name)
                    }
                case .output(let output):
                    if checkOutputs {
                        testCoverage.outputs.insert(getEnumCase(output).name)
                    }
                case .route(let route):
                    if checkRoutes {
                        testCoverage.routes.insert(getEnumCase(route).name)
                    }
                default: break
                }
            }
        }

        return TestStepResult(
            step: self,
            events: stepEvents,
            expectationErrors: expectationErrors,
            assertionErrors: assertionErrors,
            assertionWarnings: assertionWarnings,
            children: context.childStepResults,
            coverage: testCoverage
        )
    }
}

#if DEBUG
extension Component {

    @MainActor
    public static func run(_ test: Test<Model>, assertions: Set<TestAssertion>? = nil) async -> TestResult<Model> {
        guard let state = Self.state(for: test) else {
            fatalError("Could not find state")
        }

        let model = ViewModel<Model>(state: state)
        return await model.runTest(test, initialState: state, assertions: assertions ?? testAssertions)
    }
}
#endif
