//
//  File.swift
//  
//
//  Created by Yonas Kolb on 22/10/2022.
//

import Foundation
import CustomDump
import Dependencies

public struct Test<C: ComponentModel> {

    public init(_ name: String, _ state: C.State, appear: Bool = false, assertions: Set<Assertion> = Set(Assertion.allCases), file: StaticString = #file, line: UInt = #line, @TestStepBuilder _ steps: () -> [TestStep<C>]) {
        self.name = name
        self.state = state
        self.appear = appear
        self.assertions = assertions
        self.source = .capture(file: file, line: line)
        self.steps = steps()
    }

    public init(_ name: String, stateName: String, appear: Bool = false, assertions: Set<Assertion> = Set(Assertion.allCases), file: StaticString = #file, line: UInt = #line, @TestStepBuilder _ steps: () -> [TestStep<C>]) {
        self.name = name
        self.stateName = stateName
        self.appear = appear
        self.assertions = assertions
        self.source = .capture(file: file, line: line)
        self.steps = steps()
    }

    public var name: String
    public var state: C.State?
    public var stateName: String?
    public var steps: [TestStep<C>]
    public var appear: Bool
    public let source: Source
    public let assertions: Set<Assertion>

    public enum Assertion: String, CaseIterable {
        case output
        case task
        case route
    }
}

public struct TestStep<C: ComponentModel>: Identifiable {
    let type: StepType
    var source: Source
    public let id = UUID()

    public enum StepType {
        case appear
        case setDependency(Any, (inout DependencyValues) -> Void)
        case input(C.Input)
        case binding((inout C.State, Any) -> Void, PartialKeyPath<C.State>, path: String, value: Any)
        case validateState(name: String, validateState: (C.State) -> Bool)
        case validateEmptyRoute
        case validateDependency(error: String, dependency: String, validateDependency: (DependencyValues) -> Bool)
        case expectRoute(C.Route)
        case expectState((inout C.State) -> Void)
        case expectOutput(C.Output)
        case expectTask(String, successful: Bool = true)
    }

    public static func appear(file: StaticString = #file, line: UInt = #line) -> Self {
        .init(type: .appear, source: .capture(file: file, line: line))
    }

    public static func input(_ input: C.Input, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(type: .input(input), source: .capture(file: file, line: line))
    }

    public static func expectOutput(_ output: C.Output, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(type: .expectOutput(output), source: .capture(file: file, line: line))
    }

    /// validate some properties on state by returning a boolean
    public static func validateState(_ name: String, file: StaticString = #file, line: UInt = #line, _ validateState: @escaping (C.State) -> Bool) -> Self {
        .init(type: .validateState(name: name, validateState: validateState), source: .capture(file: file, line: line))
    }

    /// expect state to have certain properties set. Set any properties on the state that should be set. Any properties left out fill not fail the test
    public static func expectState(file: StaticString = #file, line: UInt = #line, _ modify: @escaping (inout C.State) -> Void) -> Self {
        .init(type: .expectState(modify), source: .capture(file: file, line: line))
    }

    public static func setBinding<Value>(_ keyPath: WritableKeyPath<C.State, Value>, _ value: Value, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(type: .binding({ $0[keyPath: keyPath] = $1 as! Value }, keyPath, path: keyPath.propertyName ?? "", value: value), source: .capture(file: file, line: line))
    }

    public static func setDependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, _ dependency: T, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(type: .setDependency(dependency) { $0[keyPath: keyPath] = dependency }, source: .capture(file: file, line: line))
    }

    public static func validateDependency<T>(_ error: String, _ keyPath: KeyPath<DependencyValues, T>, _ validateDependency: @escaping (T) -> Bool, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(type: .validateDependency(error: error, dependency: String(describing: T.self), validateDependency: { validateDependency($0[keyPath: keyPath]) }), source: .capture(file: file, line: line))
    }

    public static func validateEmptyRoute(file: StaticString = #file, line: UInt = #line) -> Self {
        .init(type: .validateEmptyRoute, source: .capture(file: file, line: line))
    }

    public static func expectTask(_ name: String, successful: Bool = true, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(type: .expectTask(name, successful: successful), source: .capture(file: file, line: line))
    }

    public static func expectRoute(_ route: C.Route, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(type: .expectRoute(route), source: .capture(file: file, line: line))
    }

}

extension TestStep {


}

extension TestStep {

    public var title: String {
        switch type {
            case .appear:
                return "Appear"
            case .setDependency:
                return "Set Dependency"
            case .input:
                return "Input"
            case .binding:
                return "Binding"
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
        if let details = details {
            string += ": \(details)"
        }
        return string
    }

    public var details: String? {
        switch type {
            case .appear:
                return nil
            case .setDependency(let dependency, _):
                return "\(String(describing: Swift.type(of: dependency)))"
            case .input(let input):
                return "\(getEnumCase(input).name)"
            case .binding(_, _, let path, let value):
                return "\(path) = \(value)"
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
    public static func buildBlock<C: ComponentModel>() -> [TestStep<C>] { [] }
    public static func buildBlock<C: ComponentModel>(_ tests: TestStep<C>...) -> [TestStep<C>] { tests }
    public static func buildBlock<C: ComponentModel>(_ tests: [TestStep<C>]) -> [TestStep<C>] { tests }
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

public struct TestStepResult<C: ComponentModel>: Identifiable {
    public var id: UUID { step.id }
    public var step: TestStep<C>
    public var events: [ComponentEvent]
    public var errors: [TestError]
    public var success: Bool { errors.isEmpty }
}

public struct TestResult<C: ComponentModel> {
    public let steps: [TestStepResult<C>]
    public var success: Bool { errors.isEmpty && steps.allSatisfy(\.success) }
    public var assertionErrors: [TestError]
    public var stepErrors: [TestError] { steps.reduce([]) { $0 + $1.errors } }
    public var errors: [TestError] { assertionErrors + stepErrors }
}

extension ViewModel {

    @MainActor
    public func runTest(_ test: Test<Model>, initialState: Model.State, delay: TimeInterval = 0, sendEvents: Bool = false, stepComplete: ((TestStepResult<Model>) -> Void)? = nil) async -> TestResult<Model> {

        // setup dependencies
        var testDependencyValues = DependencyValues._current
        testDependencyValues.context = .preview

        // handle events
        var events: [ComponentEvent] = []
        let eventsSubscription = self.events.sink { event in
            events.append(event)
        }

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

        // setup state
        state = initialState

        // run task
        if test.appear {
            await appear()
        }

        var stepResults: [TestStepResult<Model>] = []
        let sleepDelay = 1_000_000_000.0 * delay
        for step in test.steps {
            var stepEvents: [ComponentEvent] = []
            let stepEventsSubscription = self.events.sink { event in
                stepEvents.append(event)
            }
            var stepErrors: [TestError] = []
            switch step.type {
                case .appear:
                    await DependencyValues.withValues { dependencyValues in
                        dependencyValues = testDependencyValues
                    } operation: {
                        await appear()
                    }
                case .input(let input):
                    if delay > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(sleepDelay))
                    }
                    await DependencyValues.withValues { dependencyValues in
                        dependencyValues = testDependencyValues
                    } operation: {
                        await processInput(input, source: step.source, sendEvents: true)
                    }
                case .binding(let mutate, _, _, let value):
                    if let string = value as? String, string.count > 1, string != "", sleepDelay > 0 {
                        let sleepTime = sleepDelay/(Double(string.count))
                        var currentString = ""
                        for character in string {
                            currentString.append(character)
                            mutate(&state, currentString)
                            if sleepTime > 0 {
                                try? await Task.sleep(nanoseconds: UInt64(sleepTime))
                            }
                        }
//                    } else if let date = value as? Date, sleepDelay > 0 {
//                        if delay > 0 {
//                            try? await Task.sleep(nanoseconds: UInt64(sleepDelay))
//                        }
//                        //TODO: fix. Preview not showing steps
//                        let oldDate = state[keyPath: keyPath] as? Date ?? Date()
//                        var currentDate = oldDate
//                        let calendar = Calendar.current
//                        let components: [Calendar.Component] = [.year, .day, .hour, .minute]
//                        for component in components {
//                            let newComponentValue = calendar.component(component, from: date)
//                            let oldComponentValue = calendar.component(component, from: currentDate)
//                            if oldComponentValue != newComponentValue, let modifiedDate = calendar.date(bySetting: component, value: newComponentValue, of: currentDate) {
//                                currentDate = modifiedDate
//                                mutate(&state, currentDate)
//                                try? await Task.sleep(nanoseconds: UInt64(sleepDelay))
//                            }
//                        }
//                        mutate(&state, value)
                    } else {
                        if delay > 0 {
                            try? await Task.sleep(nanoseconds: UInt64(sleepDelay))
                        }
                        mutate(&state, value)
                    }
                case .validateState(_, let validateState):
                    let valid = validateState(state)
                    if !valid {
                        stepErrors.append(TestError(error: "Invalid State", source: step.source))
                    }
                case .validateDependency(let error, let dependency, let validateDependency):
                    let valid = validateDependency(testDependencyValues)
                    if !valid {
                        stepErrors.append(TestError(error: "Invalid \(dependency): \(error)", source: step.source))
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
                    var foundRoute: Model.Route?
                    for (index, event) in events.enumerated() {
                        switch event.type {
                            case .route(let route):
                                if foundRoute == nil, let route = route as? Model.Route {
                                    foundRoute = route
                                    events.remove(at: index)
                                    break
                                }
                            default: break
                        }
                    }
                    if let foundRoute {
                        if let difference = diff(foundRoute, route) {
                            stepErrors.append(TestError(error: "Unexpected route value \(getEnumCase(foundRoute).name)", diff: difference, source: step.source))
                        }
                    } else {
                        stepErrors.append(TestError(error: "Route \(getEnumCase(route).name) was not sent", source: step.source))
                    }
                case .expectOutput(let output):
                    var foundOutput: Model.Output?
                    for (index, event) in events.enumerated() {
                        switch event.type {
                            case .output(let output):
                                if foundOutput == nil, let output = output as? Model.Output {
                                    foundOutput = output
                                    events.remove(at: index)
                                    break
                                }
                            default: break
                        }
                    }
                    if let foundOutput {
                        if let difference = diff(foundOutput, output) {
                            stepErrors.append(TestError(error: "Unexpected output value \(getEnumCase(foundOutput).name)", diff: difference, source: step.source))
                        }
                    } else {
                        stepErrors.append(TestError(error: "Output \(getEnumCase(output).name) was not sent", source: step.source))
                    }
                case .expectTask(let name, let successful):
                    var result: TaskResult?
                    for (index, event) in events.enumerated() {
                        switch event.type {
                            case .task(let taskResult):
                                if result == nil {
                                    result = taskResult
                                    events.remove(at: index)
                                    break
                                }
                            default: break
                        }
                    }
                    if let result {
                        switch result.result {
                            case .failure:
                                if successful {
                                    stepErrors.append(TestError(error: "Expected \(name) task to succeed, but it failed", source: step.source))
                                }
                            case .success:
                                if !successful {
                                    stepErrors.append(TestError(error: "Expected \(name) task to fail, but it succeeded", source: step.source))
                                }
                        }
                    } else {
                        stepErrors.append(TestError(error: "Task \(name) was not sent", source: step.source))
                    }
                case .setDependency(_, let modify):
                    modify(&testDependencyValues)
                case .validateEmptyRoute:
                    if let route = self.route {
                        stepErrors.append(TestError(error: "Unexpected Route \(getEnumCase(route).name)", source: step.source))
                    }
            }
            let result = TestStepResult(step: step, events: stepEvents, errors: stepErrors)
            stepComplete?(result)
            stepResults.append(result)
        }
        var assertionErrors: [TestError] = []
        for assertion in test.assertions {
            switch assertion {
                case .output:
                    for event in events {
                        switch event.type {
                            case .output(let output):
                                assertionErrors.append(TestError(error: "Output \(getEnumCase(output).name) was not handled", source: test.source))
                            default: break
                        }
                    }
                case .task:
                    for event in events {
                        switch event.type {
                            case .task(let result):
                                assertionErrors.append(TestError(error: "Task \(result.name) was not handled", source: test.source))
                            default: break
                        }
                    }
                case .route:
                    for event in events {
                        switch event.type {
                            case .route(let route):
                                assertionErrors.append(TestError(error: "Route \(getEnumCase(route).name) was not handled", source: test.source))
                            default: break
                        }
                    }
            }
        }
        return TestResult(steps: stepResults, assertionErrors: assertionErrors)
    }
}
