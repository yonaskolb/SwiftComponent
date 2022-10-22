//
//  File.swift
//  
//
//  Created by Yonas Kolb on 22/10/2022.
//

import Foundation
import CustomDump

public struct Test<C: Component> {
    public init(_ name: String, _ initialState: C.State, steps: [Test<C>.Step]) {
        self.name = name
        self.initialState = initialState
        self.steps = steps
    }

    var name: String
    var initialState: C.State
    var steps: [Step]

    public enum Step {
        case task
        case action(C.Action)
        case binding((inout C.State, Any) -> Void, Any)
        case validateState(_ error: String? = nil, _ validateState: (C.State) -> Bool)
        case expectState((inout C.State) -> Void)

        public static func setBinding<Value>(_ keyPath: WritableKeyPath<C.State, Value>, _ value: Value) -> Step {
            .binding({ $0[keyPath: keyPath] = $1 as! Value }, value)
        }
    }
}

@resultBuilder
public struct TestBuilder {
    public static func buildBlock<ComponentType: Component>() -> [Test<ComponentType>] { [] }
    public static func buildBlock<ComponentType: Component>(_ tests: Test<ComponentType>...) -> [Test<ComponentType>] { tests }
    public static func buildBlock<ComponentType: Component>(_ tests: [Test<ComponentType>]) -> [Test<ComponentType>] { tests }
}

struct TestError: CustomStringConvertible, Identifiable, Equatable {
    let error: String
    let errorDetail: String?
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

    func runTest(_ test: Test<C>, delay: TimeInterval) async -> [TestError] {
        state = test.initialState
        await component.task(model: componentModel)
        var errors: [TestError] = []
        for step in test.steps {
            let sleepDelay = 1_000_000_000.0 * delay
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(sleepDelay))
            }
            switch step {
                case .task:
                    await task()
                case .action(let action):
                    await component.handle(action: action, model: componentModel)
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
                        errors.append(TestError(error: error ?? "UnexpectedState", errorDetail: nil))
                    }
                case .expectState(let modify):
                    let currentState = state
                    var modifiedState = state
                    modify(&modifiedState)
                    if let difference = diff(modifiedState, currentState) {
                        errors.append(TestError(error: "UnexpectedState", errorDetail: difference))
                    }
            }
        }
        return errors
    }
}
