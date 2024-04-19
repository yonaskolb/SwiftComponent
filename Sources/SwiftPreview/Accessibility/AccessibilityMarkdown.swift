#if os(iOS)
import Foundation
import SwiftUI
import UIKit
import AccessibilitySnapshotCore
import RegexBuilder

extension AccessibilityHierarchy {

    public func markdown() -> String {
        self.filter { !$0.description.trimmingCharacters(in: .whitespaces).isEmpty }
            .enumerated()
            .map { $1.markdown(index: $0) }
            .joined(separator: "\n\n")
    }
}

extension AccessibilityMarker {

    func markdown(index: Int) -> String {
        var hint = self.hint
        var action: String?
        if #available(iOS 16.0, *), let existingHint = hint {
            let regex  = #/action: (.*)/#
            if let match = existingHint.firstMatch(of: regex) {
                let actionString = match.output.1
                action = String(actionString)
                hint = existingHint.replacing(regex, with: "")
            }
        }

        var string = ""
        if let type {
            switch type.type {
            case .image:
                string += "🖼️ " + type.content
            case .button:
                string += "[\(type.content)](\(action ?? ""))"
            case .heading:
                string += "#### \(type.content)"
            }
        } else {
            string += description
        }

        if let hint, !hint.isEmpty {
            string += " (\(hint))"
        }
        if !customActions.isEmpty {
            string += "\n\(customActions.map { "  - [\($0)]()" }.joined(separator: "\n"))"
        }
        return string
    }
}

struct A11yMarkdown_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            Text(AccessibilityExampleView().accessibilityHierarchy().markdown())
                .padding()
        }
    }
}
#endif
