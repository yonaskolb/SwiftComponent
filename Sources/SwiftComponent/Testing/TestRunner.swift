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
            if event.componentPath == path {
                stepEvents.append(event)
            }
        }
        _ = stepEventsSubscription // hide warning
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
                case .expectRoute(_, let expectedState, let getRoute):
                    let foundRoute: Model.Route? = findEventValue { event in
                        if case .route(let route) = event.type, let route = route as? Model.Route {
                            return route
                        }
                        return nil
                    }
                    if let route = foundRoute {
                        if let foundState = getRoute(route) {
                            if let difference = diff(foundState, expectedState) {
                                stepErrors.append(TestError(error: "Unexpected route state \(getEnumCase(route).name.quoted)", diff: difference, source: source))
                            }
                        } else {
                            stepErrors.append(TestError(error: "Unexpected route \(getEnumCase(route).name.quoted)", source: source))
                        }
                        // TODO: compare nested route
                    } else {
                        stepErrors.append(TestError(error: "Unexpected empty route", source: source))
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

        stepErrors += context.assertions.assert(events: stepEvents, source: source)

        return TestStepResult(step: self, events: stepEvents, errors: stepErrors, children: context.childStepResults)
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
