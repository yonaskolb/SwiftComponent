import SwiftUI

struct PreviewReferenceKey: EnvironmentKey {

    static var defaultValue: Bool = false
}

extension EnvironmentValues {

    public var isPreviewReference: Bool {
        get {
            self[PreviewReferenceKey.self]
        }
        set {
            self[PreviewReferenceKey.self] = newValue
        }
    }
}

extension View {
    /// disables component views from calling their appearance task
    public func previewReference() -> some View {
        self.environment(\.isPreviewReference, true)
    }
}
