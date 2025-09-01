import Foundation
import SwiftUI

public struct SnapshotModifier {
    
    var apply: (AnyView) -> AnyView
    
    public static func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> Self {
        SnapshotModifier {
            AnyView($0.environment(keyPath, value))
        }
    }
    
    func render(_ view: some View) -> AnyView {
        apply(AnyView(view))
    }
}

extension Component {
    
    /// Returns all snapshots, both static and those made within tests by running those tests
    @MainActor
    public static func allSnapshots() async -> [ComponentSnapshot<Model>] {
        var allSnapshots = self.snapshots
        for test in tests {
            // only run tests if they contain snapshots steps, otherwise we can skip for performance
            let testContainsSnapshots = test.steps.contains { !$0.snapshots.isEmpty }
            if testContainsSnapshots {
                let testSnapshots = await run(test, assertions: [], onlyCollectSnapshots: true).snapshots
                allSnapshots.append(contentsOf: testSnapshots)
            }
        }
        return allSnapshots
    }
    
    /// must be called from a test target with an app host
    @MainActor
    public static func generateSnapshots(
        size: CGSize,
        files: Set<SnapshotFile> = [.image],
        snapshotDirectory: URL? = nil,
        variants: [String: [SnapshotModifier]] = [:],
        file: StaticString = #file
    ) async throws -> Set<URL> {
        let snapshots = await allSnapshots()
        var snapshotPaths: Set<URL> = []
        for snapshot in snapshots {
            let filePaths = try await write(
                snapshot: snapshot,
                size: size,
                files: files,
                snapshotDirectory: snapshotDirectory,
                variants: variants,
                file: file
            )
            snapshotPaths = snapshotPaths.union(filePaths)
        }
        return snapshotPaths
    }
        
    
    @MainActor
    public static func write(
        snapshot: ComponentSnapshot<Model>,
        size: CGSize,
        files: Set<SnapshotFile> = [.image],
        snapshotDirectory: URL? = nil,
        variants: [String: [SnapshotModifier]] = [:],
        file: StaticString = #file
    ) async throws -> [URL] {
        try await write(
            view: view(snapshot: snapshot).previewReference(),
            state: snapshot.state,
            name: "\(name).\(snapshot.name)",
            size: size,
            files: files,
            snapshotDirectory: snapshotDirectory,
            variants: variants,
            file: file
        )
    }
    
    @MainActor
    static func write<V: View>(
        view: V,
        state: Model.State,
        name: String,
        size: CGSize,
        files: Set<SnapshotFile> = [.image],
        snapshotDirectory: URL? = nil,
        variants: [String: [SnapshotModifier]],
        file: StaticString = #file
    ) async throws -> [URL] {

        var writtenFiles: [URL] = []
        let fileUrl = URL(fileURLWithPath: "\(file)", isDirectory: false)

        let snapshotsPath = snapshotDirectory ??
        fileUrl
            .deletingLastPathComponent()
            .appendingPathComponent("Snapshots")

        try FileManager.default.createDirectory(at: snapshotsPath, withIntermediateDirectories: true)
        let filePath = snapshotsPath.appendingPathComponent(name)

		#if canImport(UIKit)
        // accessibility markdown
        if files.contains(.accessibilty) {
            let accessibilityFilePath = filePath.appendingPathExtension("md")
            let accessibilitySnapshot = view.accessibilityHierarchy().markdown()
            try accessibilitySnapshot.data(using: .utf8)?.write(to: accessibilityFilePath)
            writtenFiles.append(accessibilityFilePath)
        }

        // image
        if files.contains(.image) {
            if variants.isEmpty {
                let imageFilePath = filePath.appendingPathExtension("png")
                let imageSnapshot = view.snapshot(size: size)
                try imageSnapshot.pngData()?.write(to: imageFilePath)
                writtenFiles.append(imageFilePath)
            } else {
                for (variant, environments) in variants {
                    var modifiedView = AnyView(view)
                    for environment in environments {
                        modifiedView = environment.render(modifiedView)
                    }
                    let imageSnapshot = modifiedView.snapshot(size: size)
                    let imageFilePath = snapshotsPath.appendingPathComponent("\(name).\(variant)").appendingPathExtension("png")
                    try imageSnapshot.pngData()?.write(to: imageFilePath)
                    writtenFiles.append(imageFilePath)
                }
            }
        }
		#endif
        // state
        if files.contains(.state) {
            let stateFilePath = filePath.appendingPathExtension("swift")
            let stateString = dumpToString(state)
            try stateString.data(using: .utf8)?.write(to: stateFilePath)
            writtenFiles.append(stateFilePath)
        }
        
        return writtenFiles
    }
}

public enum SnapshotFile {
    case image
    case accessibilty
    case state
}

#if os(iOS)
extension View {
    @MainActor
    func snapshot(size: CGSize) -> UIImage {
        let rootView = self
            .edgesIgnoringSafeArea(.top)
        let renderer = UIGraphicsImageRenderer(size: size)

        return rootView.renderView(in: .init(origin: .zero, size: size)) { view in
            renderer.image { _ in
                view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
            }
        }
    }
}
#endif
