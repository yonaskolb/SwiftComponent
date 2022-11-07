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

    public init(_ name: String, _ state: C.State, runViewTask: Bool = false, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line, @TestStepBuilder _ steps: () -> [TestStep<C>]) {
        self.name = name
        self.state = state
        self.runViewTask = runViewTask
        self.sourceLocation = .init(file: file, fileID: fileID, line: line)
        self.steps = steps()
    }

    public init(_ name: String, stateName: String, runViewTask: Bool = false, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line, @TestStepBuilder _ steps: () -> [TestStep<C>]) {
        self.name = name
        self.stateName = stateName
        self.runViewTask = runViewTask
        self.sourceLocation = .init(file: file, fileID: fileID, line: line)
        self.steps = steps()
    }

    public var name: String
    public var state: C.State?
    public var stateName: String?
    public var steps: [TestStep<C>]
    public var runViewTask: Bool
    public let sourceLocation: SourceLocation
}

public struct TestStep<C: ComponentModel>: Identifiable {
    let type: StepType
    var sourceLocation: SourceLocation
    public let id = UUID()

    public enum StepType {
        case viewTask
        case setDependency(Any, (inout DependencyValues) -> Void)
        case input(C.Input)
        case binding((inout C.State, Any) -> Void, PartialKeyPath<C.State>, path: String, value: Any)
        case validateState(error: String, validateState: (C.State) -> Bool)
        case validateDestination(C.Destination?)
        case expectState((inout C.State) -> Void)
        case expectOutput(C.Output)
        case validateDependency(error: String, dependency: String, validateDependency: (DependencyValues) -> Bool)
    }

    public static func runViewTask(file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line) -> Self {
        .init(type: .viewTask, sourceLocation: .capture(file: file, fileID: fileID, line: line))
    }

    public static func input(_ input: C.Input, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line) -> Self {
        .init(type: .input(input), sourceLocation: .capture(file: file, fileID: fileID, line: line))
    }

    public static func expectOutput(_ output: C.Output, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line) -> Self {
        .init(type: .expectOutput(output), sourceLocation: .capture(file: file, fileID: fileID, line: line))
    }

    public static func validateState(_ error: String, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line, _ validateState: @escaping (C.State) -> Bool) -> Self {
        .init(type: .validateState(error: error, validateState: validateState), sourceLocation: .capture(file: file, fileID: fileID, line: line))
    }

    public static func expectState(file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line, _ modify: @escaping (inout C.State) -> Void) -> Self {
        .init(type: .expectState(modify), sourceLocation: .capture(file: file, fileID: fileID, line: line))
    }

    public static func setBinding<Value>(_ keyPath: WritableKeyPath<C.State, Value>, _ value: Value, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line) -> Self {
        .init(type: .binding({ $0[keyPath: keyPath] = $1 as! Value }, keyPath, path: keyPath.propertyName ?? "", value: value), sourceLocation: .capture(file: file, fileID: fileID, line: line))
    }

    public static func setDependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, _ dependency: T, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line) -> Self {
        .init(type: .setDependency(dependency) { $0[keyPath: keyPath] = dependency }, sourceLocation: .capture(file: file, fileID: fileID, line: line))
    }

    public static func validateDependency<T>(_ error: String, _ keyPath: KeyPath<DependencyValues, T>, _ validateDependency: @escaping (T) -> Bool, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line) -> Self {
        .init(type: .validateDependency(error: error, dependency: String(describing: T.self), validateDependency: { validateDependency($0[keyPath: keyPath]) }), sourceLocation: .capture(file: file, fileID: fileID, line: line))
    }

    public static func validateDestination(_ destination: C.Destination?, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line) -> Self {
        .init(type: .validateDestination(destination), sourceLocation: .capture(file: file, fileID: fileID, line: line))
    }

}

extension TestStep {


}

extension TestStep {

    public var title: String {
        switch type {
            case .viewTask:
                return "View task"
            case .setDependency:
                return "Set Dependency"
            case .input:
                return "Input"
            case .binding:
                return "Binding"
            case .validateState:
                return "Validate State"
            case .validateDestination:
                return "Validate Destination"
            case .expectState:
                return "Expect State"
            case .expectOutput:
                return "Expect Output"
            case .validateDependency:
                return "Validate Dependency"
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
            case .viewTask:
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
            case .validateDestination(let destination):
                if let destination {
                    return getEnumCase(destination).name
                } else {
                    return "none"
                }
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
    public let sourceLocation: SourceLocation
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
    public var success: Bool { steps.allSatisfy(\.success) }
    public var errors: [TestError] { steps.reduce([]) { $0 + $1.errors } }
}

extension ViewModel {

    @MainActor
    public func runTest(_ test: Test<Model>, initialState: Model.State, delay: TimeInterval = 0, sendEvents: Bool = false, stepComplete: ((TestStepResult<Model>) -> Void)? = nil) async -> TestResult<Model> where Model.Output: Equatable {

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

        // setup state
        state = initialState

        // run task
        if test.runViewTask {
            await task()
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
                case .viewTask:
                    await DependencyValues.withValues { dependencyValues in
                        dependencyValues = testDependencyValues
                    } operation: {
                        await task()
                    }
                case .input(let input):
                    if delay > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(sleepDelay))
                    }
                    await DependencyValues.withValues { dependencyValues in
                        dependencyValues = testDependencyValues
                    } operation: {
                        await processInput(input, sourceLocation: step.sourceLocation, sendEvents: true)
                    }
                case .binding(let mutate, _, _, let value):
                    if delay > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(sleepDelay))
                    }
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

                        mutate(&state, value)
                    }
                case .validateState(_, let validateState):
                    let valid = validateState(state)
                    if !valid {
                        stepErrors.append(TestError(error: "Invalid State", sourceLocation: step.sourceLocation))
                    }
                case .validateDependency(let error, let dependency, let validateDependency):
                    let valid = validateDependency(testDependencyValues)
                    if !valid {
                        stepErrors.append(TestError(error: "Invalid \(dependency): \(error)", sourceLocation: step.sourceLocation))
                    }
                case .expectState(let modify):
                    let currentState = state
                    var expectedState = state
                    modify(&expectedState)
                    if let difference = diff(expectedState, currentState) {
                        stepErrors.append(TestError(error: "Unexpected State", diff: difference, sourceLocation: step.sourceLocation))
                    }
                case .expectOutput(let output):
                    var foundOutput: Model.Output?
                    for event in events.reversed() {
                        switch event.type {
                            case .output(let outputEvent):
                                if let ouput = outputEvent as? Model.Output {
                                    foundOutput = ouput
                                }
                                break
                            default: break
                        }
                    }
                    if let foundOutput {
                        if let difference = diff(foundOutput, output) {
                            stepErrors.append(TestError(error: "Unexpected value \(getEnumCase(foundOutput).name)", diff: difference, sourceLocation: step.sourceLocation))
                        }
                    } else {
                        stepErrors.append(TestError(error: "Not Found", sourceLocation: step.sourceLocation))
                    }
                case .setDependency(_, let modify):
                    modify(&testDependencyValues)
                case .validateDestination(let destination):
                    if let difference = diff(destination, self.destination) {
                        stepErrors.append(TestError(error: "Unexpected Destination", diff: difference, sourceLocation: step.sourceLocation))
                    }
            }
            let result = TestStepResult(step: step, events: stepEvents, errors: stepErrors)
            stepComplete?(result)
            stepResults.append(result)
        }
        return TestResult(steps: stepResults)
    }
}
