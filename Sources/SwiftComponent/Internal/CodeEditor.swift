import Foundation
import SwiftParser
import SwiftSyntax

class CodeParser {

    let originalSource: String
    let syntax: SourceFileSyntax

    init(source: String) {
        originalSource = source
        syntax = Parser.parse(source: source)
    }

    var modelSource: Codeblock? {
        syntax.getStruct(type: "ComponentModel").map(Codeblock.init)
    }

    var viewSource: Codeblock? {
        syntax.getStruct(type: "ComponentView").map(Codeblock.init)
    }

    var componentSource: Codeblock? {
        syntax.getStruct(type: "Component").map(Codeblock.init)
    }
}

class CodeRewriter: SyntaxRewriter {

    var blocks: [Codeblock]

    init(blocks: [Codeblock]) {
        self.blocks = blocks
    }

    func rewrite(_ tree: SourceFileSyntax) -> SourceFileSyntax {
        let updated = visit(tree)
        return updated
    }

    override func visit(_ node: MemberBlockSyntax) -> MemberBlockSyntax {
        for block in blocks {
            if block.syntax.id == node.id {
                var parser = Parser(block.source)
                return MemberBlockSyntax.parse(from: &parser)
            }
        }
        return node
    }
}

struct Codeblock {
    let syntax: SyntaxProtocol
    var source: String {
        didSet {
            changed = true
        }
    }
    var changed = false

    init(syntax: SyntaxProtocol) {

        if let block: MemberBlockSyntax = syntax.getChild() {
            self.source = block.description
            self.syntax = block
        } else {
            self.source = ""
            self.syntax = syntax
        }
    }
}

extension CodeParser {

    func getState() -> String? {
        guard
            let structSyntax = syntax.getStruct(id: "State"),
            let block = structSyntax.children(viewMode: .sourceAccurate).compactMap( { $0.as(MemberBlockSyntax.self) }).first,
            let declarationList = block.children(viewMode: .sourceAccurate).compactMap( { $0.as(MemberBlockItemListSyntax.self) }).first
        else { return nil }
        let string = declarationList.children(viewMode: .sourceAccurate)
            .map { $0.description }
            .joined(separator: "")
            .trimmingCharacters(in: .newlines)
        return string// + "\n\n" + declarationList.debugDescription(includeChildren: true, includeTrivia: false)
    }
}

extension SyntaxProtocol {

    func getStruct(type: String) -> StructDeclSyntax? {
        getChild { structSyntax in
            guard
                let typeClause: InheritedTypeListSyntax = structSyntax.getChild(),
                let _: IdentifierTypeSyntax = typeClause.getChild(compare: { $0.name.text == type })
            else { return false }
            return true
        }
    }

    func getStruct(id: String) -> StructDeclSyntax? {
        getChild { $0.name.description == id }
    }

    func getChild<ChildType: SyntaxProtocol>(compare: (ChildType) -> Bool = { _ in true })  -> ChildType? {
        for child in children(viewMode: .sourceAccurate) {
            if let structSyntax = child.as(ChildType.self), compare(structSyntax) {
                return structSyntax
            } else if let childState = child.getChild(compare: compare) {
                return childState
            }
        }
        return nil
    }
}
