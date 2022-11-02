//
//  File.swift
//  
//
//  Created by Yonas Kolb on 22/10/2022.
//

import Foundation
import CustomDump
import Dependencies

public struct Test<C: Component> {

    public init(_ name: String, _ initialState: C.State, runViewTask: Bool = false, @TestStepBuilder _ steps: () -> [Test<C>.Step]) {
        self.name = name
        self.initialState = initialState
        self.runViewTask = runViewTask
        self.steps = steps()
    }

    var name: String
    var initialState: C.State
    var steps: [Step]
    var runViewTask: Bool

    public struct Step {
        let type: StepType
        var sourceLocation: SourceLocation

        public enum StepType {
            case viewTask
            case setDependency((inout DependencyValues) -> Void)
            case action(C.Action)
            case binding((inout C.State, Any) -> Void, PartialKeyPath<C.State>, Any)
            case validateState(error: String, validateState: (C.State) -> Bool)
            case expectState((inout C.State) -> Void)
            case expectOutput(C.Output)
        }

        public static func runViewTask(file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line) -> Self {
            .init(type: .viewTask, sourceLocation: .capture(file: file, fileID: fileID, line: line))
        }

        public static func sendAction(_ action: C.Action, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line) -> Self {
            .init(type: .action(action), sourceLocation: .capture(file: file, fileID: fileID, line: line))
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
            .init(type: .binding({ $0[keyPath: keyPath] = $1 as! Value }, keyPath, value), sourceLocation: .capture(file: file, fileID: fileID, line: line))
        }

        public static func setDependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, _ dependency: T, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line) -> Self {
            .init(type: .setDependency { $0[keyPath: keyPath] = dependency }, sourceLocation: .capture(file: file, fileID: fileID, line: line))
        }
    }
}


@resultBuilder
public struct TestBuilder {
    public static func buildBlock<ComponentType: Component>() -> [Test<ComponentType>] { [] }
    public static func buildBlock<ComponentType: Component>(_ tests: Test<ComponentType>...) -> [Test<ComponentType>] { tests }
    public static func buildBlock<ComponentType: Component>(_ tests: [Test<ComponentType>]) -> [Test<ComponentType>] { tests }
}

@resultBuilder
public struct TestStepBuilder {
    public static func buildBlock<ComponentType: Component>() -> [Test<ComponentType>.Step] { [] }
    public static func buildBlock<ComponentType: Component>(_ tests: Test<ComponentType>.Step...) -> [Test<ComponentType>.Step] { tests }
    public static func buildBlock<ComponentType: Component>(_ tests: [Test<ComponentType>.Step]) -> [Test<ComponentType>.Step] { tests }
}

struct TestError: CustomStringConvertible, Identifiable, Hashable {
    var error: String
    var errorDetail: String?
    let sourceLocation: SourceLocation
    let id = UUID()

    var description: String {
        var string = error
        if let errorDetail {
            string += ":\n\(errorDetail)"
        }
        return string
    }
}

extension ViewModel {

    @MainActor
    func runTest(_ test: Test<C>, delay: TimeInterval, sendEvents: Bool) async -> [TestError] where C.Output: Equatable {

        // setup dependencies
        var testDependencyValues = DependencyValues._current
        testDependencyValues.context = .test

        // handle events
        let sendEventsValue = self.sendEvents
        self.sendEvents = sendEvents
        defer {
            self.sendEvents = sendEventsValue
        }

        // setup state
        state = test.initialState

        // run task
        if test.runViewTask {
            await task()
        }
        
        var errors: [TestError] = []
        let sleepDelay = 1_000_000_000.0 * delay
        for step in test.steps {
            switch step.type {
                case .viewTask:
                    await DependencyValues.withValues { dependencyValues in
                        dependencyValues = testDependencyValues
                    } operation: {
                        await task()
                    }
                case .action(let action):
                    if delay > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(sleepDelay))
                    }
                    await DependencyValues.withValues { dependencyValues in
                        dependencyValues = testDependencyValues
                    } operation: {
                        await handleAction(action, sourceLocation: step.sourceLocation)
                    }
                case .binding(let mutate, let keyPath, let value):
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
                case .validateState(let error, let validateState):
                    let valid = validateState(state)
                    if !valid {
                        errors.append(TestError(error: "State validation failed", errorDetail: error, sourceLocation: step.sourceLocation))
                    }
                case .expectState(let modify):
                    let currentState = state
                    var modifiedState = state
                    modify(&modifiedState)
                    if let difference = diff(modifiedState, currentState) {
                        errors.append(TestError(error: "Unexpected State", errorDetail: difference, sourceLocation: step.sourceLocation))
                    }
                case .expectOutput(let output):
                    var foundOutput: C.Output?
                    for event in events.reversed() {
                        switch event.type {
                            case .output(let outputEvent):
                                foundOutput = outputEvent
                                break
                            default: break
                        }
                    }
                    if let foundOutput {
                        if let difference = diff(foundOutput, output) {
                            errors.append(TestError(error: "Unexpected Output.\(getEnumCase(output).name) value", errorDetail: difference, sourceLocation: step.sourceLocation))
                        }
                    } else {
                        errors.append(TestError(error: "Expected Output.\(getEnumCase(output).name)", sourceLocation: step.sourceLocation))
                    }
                case .setDependency(let modify):
                    modify(&testDependencyValues)
            }
        }
        return errors
    }
}
