import Foundation
import SwiftParser
import SwiftSyntax
import ArgumentParser

struct GenerateComponents: ParsableCommand {

    static var configuration = CommandConfiguration(
        commandName: "generate-components",
        abstract: "Generates a file containing all the Components in the directory"
    )

    @Argument var directory: String
    @Argument var outputFile: String

    mutating func run() throws {
        let files = try FileManager.default.subpathsOfDirectory(atPath: directory)
        var componentList: [String] = []
        for file in files {
            if file.hasSuffix(".swift") {
                let filePath = "\(directory)/\(file)"
                if let contents = FileManager.default.contents(atPath: filePath), let source = String(data: contents, encoding: .utf8) {
                    // TODO: enable better parsing. It's slow right now compared to regex
//                    let syntax = Parser.parse(source: source)
//                    if let component = syntax.getStruct(type: "Component") {
//                        componentList.append(component.name.text)
//                    }
                    if #available(macOS 13.0, iOS 16.0, *) {
                        let regex = #/(struct|extension) (?<component>.*):.*Component[, ]/#
                        if let match = try regex.firstMatch(in: source) {
                            componentList.append(String(match.output.component))
                        }
                    }
                }
            }
        }
        componentList.sort()
        print("Found \(componentList.count) Components in \(directory):")
        print(componentList.joined(separator: "\n"))

        let file = """
        import SwiftComponent

        #if DEBUG
        public let components: [any Component.Type] = [
            \(componentList.map { "\($0).self" }.joined(separator: ",\n    "))
        ]
        #else
        public let components: [any Component.Type] = []
        #endif
        """
        let data = file.data(using: .utf8)!
        do {
            try data.write(to: URL(fileURLWithPath: outputFile))
        } catch {
            print(error)
        }
    }
}

extension SyntaxProtocol {

    func getStruct(type: String) -> StructDeclSyntax? {
        getChild { structSyntax in
            guard
                let typeClause: InheritedTypeListSyntax = structSyntax.getChild(),
                let _ = typeClause.getChild(compare: { $0.name.text == type }) as IdentifierTypeSyntax?
            else { return false }
            return true
        }
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
