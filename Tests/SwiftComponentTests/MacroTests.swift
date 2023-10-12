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

    func testMacro() {
        assertMacro {
            """
            @ComponentModel struct Model {

                var getter: String {
                  dependencies.something
                }
                enum Action {
                    case select
                }
            
                @MainActor
                func handle(action: Action) async {
                    customFunction()
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
                enum Action {
                    case select
                }

                @MainActor
                func handle(action: Action) async {
                    customFunction()
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
}
