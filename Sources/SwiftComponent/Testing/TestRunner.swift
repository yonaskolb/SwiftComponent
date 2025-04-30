import Foundation
@_implementationOnly import Runtime

public struct TestContext<Model: ComponentModel> {
    public let model: ViewModel<Model>
    public var delay: TimeInterval
    public var assertions: [TestAssertion]
    public var runAssertions: Bool = true
    public var runExpectations: Bool = true
    public var collectTestCoverage: Bool = true
    public var childStepResults: [TestStepResult] = []
    public var stepErrors: [TestError] = []
    public var testCoverage: TestCoverage = .init()
    var snapshots: [ComponentSnapshot<Model>] = []
    var state: Model.State

    var delayNanoseconds: UInt64 { UInt64(1_000_000_000.0 * delay) }
}

extension Component {

    @MainActor
    public static func runTest(
        _ test: Test<Self>,
        model: ViewModel<Model>,
        initialState: Model.State? = nil,
        assertions: [TestAssertion],
        delay: TimeInterval = 0,
        onlyCollectSnapshots: Bool = false,
        sendEvents: Bool = false,
        stepComplete: ((TestStepResult) -> Void)? = nil
    ) async -> TestResult<Model> {
        await TestRunTask.$running.withValue(true) {
            let start = Date()
            let assertions = test.assertions ?? assertions
            
            model.store.dependencies.reset()
            model.store.dependencies.apply(test.dependencies)
            model.store.dependencies.dependencyValues.context = .preview
            model.store.children = [:]
            
            let sendEventsValue = model.store.sendGlobalEvents
            model.store.sendGlobalEvents = sendEvents
            defer {
                model.store.sendGlobalEvents = sendEventsValue
            }
            
            if delay > 0 {
                model.store.previewTaskDelay = delay
            }
            defer {
                model.store.previewTaskDelay = 0
            }
            if let initialState {
                model.state = initialState
            }
            model.route = nil
            model.store.graph.clearRoutes()
            
            var stepResults: [TestStepResult] = []
            var context = TestContext<Model>(model: model, delay: delay, assertions: assertions, state: model.state)
            if onlyCollectSnapshots {
                context.runExpectations = false
                context.collectTestCoverage = false
                context.runAssertions = false
            }
            for step in test.steps {
                context.stepErrors = []
                var result = await TestStepID.$current.withValue(step.id) {
                    await step.runTest(context: &context)
                }
                result.stepErrors.append(contentsOf: context.stepErrors)
                stepComplete?(result)
                stepResults.append(result)
            }
            return TestResult<Model>(start: start, end: Date(), steps: stepResults, snapshots: context.snapshots)
        }
    }
}

extension TestStep {

    @MainActor
    func runTest(context: inout TestContext<Model>) async -> TestStepResult {
        var stepEvents: [Event] = []
        var unexpectedEvents: [Event] = []
        context.state = context.model.state

        let previousChildStepResults = context.childStepResults
        context.childStepResults = []
        defer {
            context.childStepResults = previousChildStepResults
        }

        let runAssertions = context.runAssertions
        let storeID = context.model.store.id

        let startingAccessedDependencies = context.model.store.dependencies.accessedDependencies
        context.model.store.dependencies.accessedDependencies = []

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

        var testCoverage = TestCoverage()
        if context.collectTestCoverage {
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

            testCoverage.dependencies = context.model.store.dependencies.accessedDependencies
            context.model.store.dependencies.accessedDependencies = startingAccessedDependencies.union(testCoverage.dependencies)
            context.testCoverage.add(testCoverage)
        }

        var expectationErrors: [TestError] = []
        if context.runExpectations {
            for expectation in expectations {
                var expectationContext = TestExpectation<Model>.Context(testContext: context, source: expectation.source, events: unexpectedEvents)
                expectation.run(&expectationContext)
                unexpectedEvents = expectationContext.events
                context.state = expectationContext.testContext.state
                expectationErrors += expectationContext.errors
            }
        }

        var assertionErrors: [TestError] = []
        var assertionWarnings: [TestError] = []
        if context.runAssertions {

            for assertion in context.assertions {
                var assertionContext = TestAssertionContext(events: unexpectedEvents, source: source, testContext: context, stepID: self.id)
                assertion.assert(context: &assertionContext)
                assertionErrors += assertionContext.errors
            }

            for assertion in [TestAssertion].all {
                if !context.assertions.contains(where: { $0.id == assertion.id }) {
                    var assertionContext = TestAssertionContext(events: unexpectedEvents, source: source, testContext: context, stepID: self.id)
                    assertion.assert(context: &assertionContext)
                    assertionWarnings += assertionContext.errors
                }
            }
        }

        context.runAssertions = runAssertions

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

extension Component {

    @MainActor
    public static func run(_ test: Test<Self>, assertions: [TestAssertion]? = nil, onlyCollectSnapshots: Bool = false) async -> TestResult<Model> {
        return await withDependencies {
            // standardise context, and prevent failures in unit tests, as dependency tracking is handled within
            $0.context = .preview
        } operation: {
            let model = ViewModel<Model>(state: test.state, environment: test.environment)
            return await runTest(
                test,
                model: model,
                assertions: assertions ?? testAssertions,
                onlyCollectSnapshots: onlyCollectSnapshots
            )
        }
    }
}

public enum TestRunTask {
    @TaskLocal public static var running = false
}
