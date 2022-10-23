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
    public init(_ name: String, _ initialState: C.State, steps: [Test<C>.Step]) {
        self.name = name
        self.initialState = initialState
        self.steps = steps
    }

    public init(_ name: String, _ initialState: C.State, @TestStepBuilder _ steps: () -> [Test<C>.Step]) {
        self.name = name
        self.initialState = initialState
        self.steps = steps()
    }

    var name: String
    var initialState: C.State
    var steps: [Step]

    public struct Step {
        let type: StepType

        public enum StepType {
            case task
            case setDependency((inout DependencyValues) -> Void)
            case action(C.Action)
            case binding((inout C.State, Any) -> Void, Any)
            case validateState(error: String, validateState: (C.State) -> Bool)
            case expectState((inout C.State) -> Void)
            case output(C.Output)
        }

        public static func task() -> Self {
            .init(type: .task)
        }

        public static func sendAction(_ action: C.Action) -> Self {
            .init(type: .action(action))
        }

        public static func expectOutput(_ output: C.Output) -> Self {
            .init(type: .output(output))
        }

        public static func validateState(_ error: String, _ validateState: @escaping (C.State) -> Bool) -> Self {
            .init(type: .validateState(error: error, validateState: validateState))
        }

        public static func expectState(_ modify: @escaping (inout C.State) -> Void) -> Self {
            .init(type: .expectState(modify))
        }

        public static func setBinding<Value>(_ keyPath: WritableKeyPath<C.State, Value>, _ value: Value) -> Self {
            .init(type: .binding({ $0[keyPath: keyPath] = $1 as! Value }, value))
        }

        public static func setDependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, _ dependency: T) -> Self {
            .init(type: .setDependency { $0[keyPath: keyPath] = dependency })
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

    func runTest(_ test: Test<C>, delay: TimeInterval) async -> [TestError] where C.Output: Equatable {
        var testDependencyValues = DependencyValues._current
        testDependencyValues.context = .test

        state = test.initialState
        await component.task(model: componentModel)
        var errors: [TestError] = []
        for step in test.steps {
            let sleepDelay = 1_000_000_000.0 * delay
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(sleepDelay))
            }
            switch step.type {
                case .task:
                    await task()
                case .action(let action):
                    await DependencyValues.withValues { dependencyValues in
                        dependencyValues = testDependencyValues
                    } operation: {
                        await component.handle(action: action, model: componentModel)
                    }


                case .binding(let mutate, let value):
                    if let string = value as? String, string.count > 1, string != "" {
                        var currentString = ""
                        mutate(&state, currentString)
                        for character in string {
                            let sleeptime = sleepDelay/(Double(string.count))
                            try? await Task.sleep(nanoseconds: UInt64(sleeptime))
                            currentString.append(character)
                            mutate(&state, currentString)
                        }
                    } else {
                        mutate(&state, value)
                    }
                case .validateState(let error, let validateState):
                    let valid = validateState(state)
                    if !valid {
                        errors.append(TestError(error: error))
                    }
                case .expectState(let modify):
                    let currentState = state
                    var modifiedState = state
                    modify(&modifiedState)
                    if let difference = diff(modifiedState, currentState) {
                        errors.append(TestError(error: "Unexpected State", errorDetail: difference))
                    }
                case .output(let output):
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
                            errors.append(TestError(error: "Unexpected Output.\(getEnumCase(output).name) value", errorDetail: difference))
                        }
                    } else {
                        errors.append(TestError(error: "Expected Output.\(getEnumCase(output).name)"))
                    }
                case .setDependency(let modify):
                    modify(&testDependencyValues)
            }
        }
        return errors
    }
}
