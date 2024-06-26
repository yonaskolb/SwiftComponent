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

extension ComponentSnapshot {

    @MainActor
    /// must be called from a test target with an app host
    public func write<V: View>(
        size: CGSize,
        with view: V,
        snapshotDirectory: String? = nil,
        file: StaticString = #file,
        variants: [String: [SnapshotModifier]] = [:]
    ) async throws -> [URL] {

        var writtenFiles: [URL] = []
        let fileUrl = URL(fileURLWithPath: "\(file)", isDirectory: false)

        let snapshotsPath = snapshotDirectory.map { URL(fileURLWithPath: $0, isDirectory: true) } ??
        fileUrl
            .deletingLastPathComponent()
            .appendingPathComponent("Snapshots")

        try FileManager.default.createDirectory(at: snapshotsPath, withIntermediateDirectories: true)
        let filePath = snapshotsPath.appendingPathComponent("\(Model.baseName).\(name)")

        let view = view.previewReference()

#if canImport(UIKit)
        // accessibility markdown
        let accessibilityFilePath = filePath.appendingPathExtension("md")
        let accessibilitySnapshot = view.accessibilityHierarchy().markdown()
        try accessibilitySnapshot.data(using: .utf8)?.write(to: accessibilityFilePath)
        writtenFiles.append(accessibilityFilePath)

        // image
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
                let imageFilePath = snapshotsPath.appendingPathComponent("\(Model.baseName).\(name).\(variant)").appendingPathExtension("png")
                try imageSnapshot.pngData()?.write(to: imageFilePath)
                writtenFiles.append(imageFilePath)
            }
        }
#endif
        // state
        let stateFilePath = filePath.appendingPathExtension("swift")
        let state = dumpToString(self.state)
        try state.data(using: .utf8)?.write(to: stateFilePath)
        writtenFiles.append(stateFilePath)
        
        return writtenFiles
    }
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
