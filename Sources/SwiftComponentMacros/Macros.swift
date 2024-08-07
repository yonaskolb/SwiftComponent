import Foundation
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MyMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ComponentModelMacro.self,
        ObservableStateMacro.self,
        ObservationStateTrackedMacro.self,
        ObservationStateIgnoredMacro.self,
        ResourceMacro.self
    ]
}
