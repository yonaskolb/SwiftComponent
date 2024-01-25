#if os(iOS)
import Foundation
import SwiftUI
import UIKit
import AccessibilitySnapshotCore

public typealias AccessibilityHierarchy = [AccessibilityMarker]

extension View {

    public func accessibilityHierarchy(frame: CGRect = CGRect(origin: .zero, size: CGSize(width: 500, height: 2000))) -> AccessibilityHierarchy {
        self.renderView(in: frame) { view in
            view.accessibilityHierarchy()
        }
    }
}

extension UIView {

    func accessibilityHierarchy() -> AccessibilityHierarchy {
        let accessibilityHierarchyParser = AccessibilityHierarchyParser()
        return accessibilityHierarchyParser.parseAccessibilityElements(in: self)
    }
}

extension AccessibilityMarker {

    enum AccessibilityMarkerType: String, CaseIterable {
        case button = "Button"
        case image = "Image"
        case heading = "Heading"
    }

    var type: (type: AccessibilityMarkerType, content: String)? {
        let string = description
        guard string.hasSuffix("."), string.count > 1 else { return nil }
        for type in AccessibilityMarkerType.allCases {
            if string.hasSuffix(". \(type.rawValue).") {
                let content = String(string.dropLast(3 + type.rawValue.count))
                return (type, content)
            }
        }
        return nil
    }
}

#endif
