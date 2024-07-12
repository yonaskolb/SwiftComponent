#if canImport(SwiftComponentMacros)
import MacroTesting
import Foundation
import XCTest
import SwiftComponentMacros

final class ObservableStateMacroTests: XCTestCase {
    override func invokeTest() {
        withMacroTesting(isRecording: false, macros: [ObservableStateMacro.self]) {
            super.invokeTest()
        }
    }

    func testEmpty() {
        assertMacro {
            """
            @ObservableState
            struct State {
                
            }
            """
        } expansion: {
            """
            struct State {

                
            @ObservationStateIgnored var _$observationRegistrar = SwiftComponent.ObservationStateRegistrar()

                
            public var _$id: SwiftComponent.ObservableStateID {

                
            _$observationRegistrar.id
                
            }

                
            public mutating func _$willModify() {

                
            _$observationRegistrar._$willModify()
                
            }
                
            }
            """
        }
    }
    
    func testProperties() {
        assertMacro {
            """
            @ObservableState
            struct State {
                var property: String
                var property2: Int
            }
            """
        } expansion: {
            """
            struct State {
                @ObservationStateTracked
                var property: String
                @ObservationStateTracked
                var property2: Int

                @ObservationStateIgnored var _$observationRegistrar = SwiftComponent.ObservationStateRegistrar()

                public var _$id: SwiftComponent.ObservableStateID {
                    _$observationRegistrar.id
                }

                public mutating func _$willModify() {
                    _$observationRegistrar._$willModify()
                }
            }
            """
        }
    }
    
    func testIgnorePropertyWrapper() {
        assertMacro {
            """
            @ObservableState
            struct State {
                @Resource var property: String
            }
            """
        } expansion: {
            """
            struct State {
                @Resource
                @ObservationStateIgnored var property: String

                @ObservationStateIgnored var _$observationRegistrar = SwiftComponent.ObservationStateRegistrar()

                public var _$id: SwiftComponent.ObservableStateID {
                    _$observationRegistrar.id
                }

                public mutating func _$willModify() {
                    _$observationRegistrar._$willModify()
                }
            }
            """
        }
    }
}
#endif
