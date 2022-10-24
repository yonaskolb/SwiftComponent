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
            case binding((inout C.State, Any) -> Void, Any)
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
            .init(type: .binding({ $0[keyPath: keyPath] = $1 as! Value }, value), sourceLocation: .capture(file: file, fileID: fileID, line: line))
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
        for step in test.steps {
            let sleepDelay = 1_000_000_000.0 * delay
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(sleepDelay))
            }
            switch step.type {
                case .viewTask:
                    await task()
                case .action(let action):
                    await DependencyValues.withValues { dependencyValues in
                        dependencyValues = testDependencyValues
                    } operation: {
                        await handleAction(action, sourceLocation: step.sourceLocation)
                    }
                case .binding(let mutate, let value):
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
                    } else {
                        mutate(&state, value)
                    }
                case .validateState(let error, let validateState):
                    let valid = validateState(state)
                    if !valid {
                        errors.append(TestError(error: error, sourceLocation: step.sourceLocation))
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
