import Foundation
import ArgumentParser

@main
struct Components: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A tool for SwiftComponent",
        subcommands: [
            GenerateComponents.self,
        ])
}
