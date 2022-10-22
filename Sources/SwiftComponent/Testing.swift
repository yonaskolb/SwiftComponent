//
//  File.swift
//  
//
//  Created by Yonas Kolb on 14/9/2022.
//

import Foundation
import SwiftUI

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

        public static func setBinding<Value>(_ keyPath: WritableKeyPath<C.State, Value>, _ value: Value) -> Step {
            .binding({ $0[keyPath: keyPath] = $1 as! Value }, value)
        }

    }
}

extension ViewModel {

    func runTest(_ test: Test<C>, delay: Double) async {
        state = test.initialState
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
            }
        }
    }
}


// #high
//extension Component {
//
//    func setComponentState<Value, C: Component>(for component: C.Type, _ keyPath: WritableKeyPath<State, Value>, value: Value) -> Self {
//        var state = fatalError()
//        self.state[keyPath: keyPath]
////        self.environment(keyPath, value)
//    }
//}
//
//extension View {
//
//    func actionButton<T>(action: T
//}
