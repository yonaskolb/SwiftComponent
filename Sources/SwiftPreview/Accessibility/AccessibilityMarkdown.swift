import Foundation
import SwiftUI
import UIKit
#if canImport(AccessibilitySnapshotCore)
import AccessibilitySnapshotCore

extension AccessibilityHierarchy {

    public func markdown() -> String {
        self.filter { !$0.description.trimmingCharacters(in: .whitespaces).isEmpty }
            .enumerated()
            .map { $1.markdown(index: $0) }
            .joined(separator: "\n")
    }
}

extension AccessibilityMarker {

    func markdown(index: Int) -> String {
        var string = ""
        if let type {
            switch type.type {
            case .image:
                string += "- 🖼️ " + type.content
            case .button:
                string += "- [\(type.content)]()"
            case .heading:
                if index > 0 {
                    string += "\n"
                }
                string += "#### \(type.content)"
            }
        } else {
            string += "- \(description)"
        }

        if let hint {
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
