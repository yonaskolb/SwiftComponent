import Foundation
import SwiftUI

enum PreviewColorScheme: String {
    case system
    case dark
    case light

    @AppStorage("componentPreview.colorScheme")
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
