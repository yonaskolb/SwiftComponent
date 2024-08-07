#if canImport(SwiftComponentMacros)
import MacroTesting
import Foundation
import XCTest
import SwiftComponentMacros

final class ModelMacroTests: XCTestCase {
    override func invokeTest() {
        withMacroTesting(isRecording: false, macros: [ComponentModelMacro.self]) {
            super.invokeTest()
        }
    }

    func testModel() {
        assertMacro {
            """
            @ComponentModel struct Model {

            }
            """
        } expansion: {
            """
            struct Model {

                public var context: Context

                public init(context: Context) {
                    self.context = context
                }

            }

            extension Model: ComponentModel {
            }
            """
        }
    }

    func testMainActor() {
        assertMacro {
            """
            @ComponentModel struct Model {

                var getter: String {
                  dependencies.something
                }

                @MainActor
                func customFunction() {
                }

                func customFunction() {
                }
            }
            """
        } expansion: {
            """
            struct Model {
                @MainActor

                var getter: String {
                  dependencies.something
                }

                @MainActor
                func customFunction() {
                }
                @MainActor

                func customFunction() {
                }

                public var context: Context

                public init(context: Context) {
                    self.context = context
                }
            }

            extension Model: ComponentModel {
            }
            """
        }
    }

    func testAddObservableState() {
        assertMacro {
            """
            @ComponentModel struct Model {

                struct State {

                }
            }
            """
        } expansion: {
            """
            struct Model {
                @ObservableState

                struct State {

                }

                public var context: Context

                public init(context: Context) {
                    self.context = context
                }
            }

            extension Model: ComponentModel {
            }
            """
        }
    }

    func testKeepObservableState() {
        assertMacro {
            """
            @ComponentModel struct Model {

                @ObservableState
                struct State {

                }
            }
            """
        } expansion: {
            """
            struct Model {

                @ObservableState
                struct State {

                }

                public var context: Context

                public init(context: Context) {
                    self.context = context
                }
            }

            extension Model: ComponentModel {
            }
            """
        }
    }

    func testKeepExternalObservableState() {
        assertMacro {
            """
            @ComponentModel struct Model {

                typealias State = OtherState
            }
            """
        } expansion: {
            """
            struct Model {

                typealias State = OtherState

                public var context: Context

                public init(context: Context) {
                    self.context = context
                }
            }

            extension Model: ComponentModel {
            }
            """
        }
    }
}
#endif
