import Foundation
import CustomDump

public struct TestContext<Model: ComponentModel> {
    public let model: ViewModel<Model>
    public var dependencies: DependencyValues
    public var delay: TimeInterval
    public var assertions: [TestAssertion]
    public var childStepResults: [TestStepResult] = []

    var delayNanoseconds: UInt64 { UInt64(1_000_000_000.0 * delay) }
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
        context.childStepResults = []
        let stepEventsSubscription = context.model.store.events.sink { event in
            // TODO: should probabyl check id instead
            if event.path == path {
                stepEvents.append(event)
            }
        }
        _ = stepEventsSubscription // hide warning
        await withDependencies { dependencyValues in
            dependencyValues = context.dependencies
        } operation: { @MainActor in
            await self.run(&context)
        }

        var expectationErrors: [TestError] = []
        for expectation in expectations {
            var context = TestExpectation<Model>.Context(testContext: context, source: expectation.source, events: stepEvents)
            expectation.run(&context)
            stepEvents = context.events
            expectationErrors += context.errors
        }

        var assertionErrors: [TestError] = []
        for assertion in context.assertions {
            assertionErrors += assertion.assert(events: stepEvents, source: source)
        }

        return TestStepResult(
            step: self,
            events: stepEvents,
            expectationErrors: expectationErrors,
            assertionErrors: assertionErrors,
            children: context.childStepResults)
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