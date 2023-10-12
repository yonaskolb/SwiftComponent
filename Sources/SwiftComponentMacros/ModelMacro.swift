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
            "public var context: Context",
            """
            public init(context: Context) {
                self.context = context
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

extension ComponentModelMacro: MemberAttributeMacro {

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        func hasMainActor(_ attributes: AttributeListSyntax) -> Bool {
            attributes.compactMap { $0.as(AttributeSyntax.self) }.contains { 
                print($0.attributeName.description)
                return $0.attributeName.description == "MainActor"
            }
        }
        if let syntax = member.as(FunctionDeclSyntax.self), !hasMainActor(syntax.attributes) {
            return ["@MainActor"]
        }
        if let syntax = member.as(VariableDeclSyntax.self), !hasMainActor(syntax.attributes) {
            return ["@MainActor"]
        }
        return []
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
