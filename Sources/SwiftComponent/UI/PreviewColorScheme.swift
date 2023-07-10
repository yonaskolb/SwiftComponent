import Foundation
import SwiftUI

extension View {

    func previewColorScheme() -> some View {
        modifier(PreviewColorSchemeModifier())
    }
}

struct PreviewColorSchemeModifier: ViewModifier {
    @AppStorage(PreviewColorScheme.key)
    var previewColorScheme: PreviewColorScheme = .system
    @Environment(\.colorScheme)
    var systemColorScheme: ColorScheme

    func body(content: Content) -> some View {
        content.colorScheme(previewColorScheme.colorScheme ?? systemColorScheme)
    }
}

enum PreviewColorScheme: String {
    case system
    case dark
    case light

    static let key = "componentPreview.colorScheme"

    @AppStorage(key)
    static var current: PreviewColorScheme = .system

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }

    init(colorScheme: ColorScheme) {
        switch colorScheme {
        case .light:
            self = .light
        case .dark:
            self = .dark
        @unknown default:
            self = .system
        }
    }
}

extension Color {
    static let darkBackground = Color(white: 0.15)
}
