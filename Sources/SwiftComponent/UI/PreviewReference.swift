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

struct ViewAppearanceTaskKey: EnvironmentKey {

    static var defaultValue: Bool = true
}

extension EnvironmentValues {

    public var viewAppearanceTask: Bool {
        get {
            self[ViewAppearanceTaskKey.self]
        }
        set {
            self[ViewAppearanceTaskKey.self] = newValue
        }
    }
}

extension View {
    /// disables component views from calling their appearance task
    public func previewReference() -> some View {
        self
            .environment(\.isPreviewReference, true)
            .environment(\.viewAppearanceTask, false)
    }
}
