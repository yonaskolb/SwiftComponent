import Foundation
import SwiftUI

extension ComponentSnapshot {

    @MainActor
    /// must be called from a test target with an app host
    public func write<V: View>(
        size: CGSize,
        with view: V,
        snapshotDirectory: String? = nil,
        file: StaticString = #file
    ) async throws {

        let fileUrl = URL(fileURLWithPath: "\(file)", isDirectory: false)

        let snapshotsPath = snapshotDirectory.map { URL(fileURLWithPath: $0, isDirectory: true) } ??
        fileUrl
            .deletingLastPathComponent()
            .appendingPathComponent("Snapshots")

        try FileManager.default.createDirectory(at: snapshotsPath, withIntermediateDirectories: true)
        let filePath = snapshotsPath.appendingPathComponent("\(Model.baseName).\(name)")

        let view = view.previewReference()

#if canImport(UIKit) && canImport(AccessibilitySnapshot)
        // accessibility markdown
        let accessibilitySnapshot = view.accessibilityHierarchy().markdown()
        try accessibilitySnapshot.data(using: .utf8)?.write(to: filePath.appendingPathExtension("md"))


        // image
        let imageSnapshot = view.snapshot(size: size)
        try imageSnapshot.pngData()?.write(to: filePath.appendingPathExtension("png"))
#endif
        // state
        let state = dumpToString(self.state)
        try state.data(using: .utf8)?.write(to: filePath.appendingPathExtension("txt"))

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
