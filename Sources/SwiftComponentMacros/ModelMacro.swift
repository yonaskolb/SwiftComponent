import Foundation
import SwiftSyntaxMacros
import SwiftSyntax

public struct ComponentModelMacro {}

extension ComponentModelMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.onlyStruct
        }
        // TODO: only make public if type is public
        return [
            "public let _$context: Context",
            "public let _$connections: Connections = Self.Connections()",
            """
            public init(context: Context) {
                self._$context = context
            }
            """,
        ]
    }
} 

extension ComponentModelMacro: ExtensionMacro {

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
        providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let declSyntax: DeclSyntax = """
        extension \(type.trimmed): ComponentModel {
        }
        """

        guard let extensionDecl = declSyntax.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [extensionDecl]

    }
}

// TODO: replace this when a macro can add @MainActor to the whole type
extension ComponentModelMacro: MemberAttributeMacro {

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        if let syntax = member.as(FunctionDeclSyntax.self),
            !syntax.attributes.hasAttribute("MainActor") {
            return ["@MainActor"]
        }
        if let syntax = member.as(VariableDeclSyntax.self),
            !syntax.attributes.hasAttribute("MainActor") {
            return ["@MainActor"]
        }
        
//        if let syntax = member.as(StructDeclSyntax.self),
//            syntax.name.text == "Connections",
//           !syntax.attributes.hasAttribute("MainActor"){
//            return ["@MainActor"]
//        }
        
        // add ObservableState to State
        if let syntax = member.as(StructDeclSyntax.self),
            syntax.name.text == "State",
           !syntax.attributes.hasAttribute("ObservableState"){
            return ["@ObservableState"]
        }
        
        // add ObservableState and CasePathable to Destination
        if let syntax = member.as(EnumDeclSyntax.self),
           syntax.name.text == "Destination" {
            var attributes: [AttributeSyntax] = []
            if !syntax.attributes.hasAttribute("ObservableState") {
                attributes.append("@ObservableState")
          	}
            if !syntax.attributes.hasAttribute("CasePathable") {
                attributes.append("@CasePathable")
              }
            return attributes
        }
        return []
    }
}

extension AttributeListSyntax {

    func hasAttribute(_ attribute: String) -> Bool {
        self.compactMap { $0.as(AttributeSyntax.self) }.contains {
            return $0.attributeName.description == attribute
        }
    }
}

enum MacroError: CustomStringConvertible, Error {
    case onlyStruct

    var description: String {
        switch self {
        case .onlyStruct: return "Can only be applied to a structure"
        }
    }
}
