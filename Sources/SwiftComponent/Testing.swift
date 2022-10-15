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
        case action(C.Action)
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
