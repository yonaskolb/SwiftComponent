import Foundation
import PackagePlugin
#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin
#endif

@main
struct ComponentBuilderPlugin {

    func generateComponentsCommand(executable: Path, directory: Path, output: Path) -> Command {
        .buildCommand(displayName: "Generate Component List",
                      executable: executable,
                      arguments: ["generate-components", directory, output],
                      environment: [:],
                      inputFiles: [],
                      outputFiles: [output])
    }
}

extension ComponentBuilderPlugin: BuildToolPlugin {

    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        [
            generateComponentsCommand(
                executable: try context.tool(named: "SwiftComponentCLI").path,
                directory: target.directory,
                output: context.pluginWorkDirectory.appending("Components.swift")
            )
        ]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin
extension ComponentBuilderPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        [
            generateComponentsCommand(
                executable: try context.tool(named: "SwiftComponentCLI").path,
                // TODO: The target name may not always be where we want to search for components
                directory: context.xcodeProject.directory.appending(target.displayName),
                output: context.pluginWorkDirectory.appending("Components.swift")
            )
        ]
    }
}
#endif
