//
//  File.swift
//  
//
//  Created by Yonas Kolb on 27/10/2022.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import AccessibilitySnapshotCore
import UIKit


private let accessibilityHierarchyParser = AccessibilityHierarchyParser()

extension View {

    public func accessibilityPreview() -> some View {
        let viewController = UIHostingController(rootView: self)
        viewController.view.frame.size = CGSize(width: 600, height: 10000)
        let markers = accessibilityHierarchyParser.parseAccessibilityElements(in: viewController.view)
        return AccessibilityHeirarchyView(markers: markers)
    }
}

struct AccessibilityHeirarchyView: View {

    let markers: [AccessibilityMarker]

    var body: some View {
        if markers.isEmpty {
            Text("Accessibility hierarchy not found")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(markers.enumerated()), id: \.offset) { index, marker in
                        HStack {
                            markerView(marker)
                            Spacer()
                        }

                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    func markerView(_ marker: AccessibilityMarker) -> some View {
        if let type = marker.type {
            switch type.type {
                case .button:
                    Button(action: {}) {
                        Text(type.content)
                        .bold()
                    }
                case .heading:
                    Text(type.content)
                        .bold()
                        .font(.title2)
                        .padding(.bottom, 8)
                case .image:
                    Text("🌅 " + marker.description)
            }
        } else {
            Text(marker.description)
        }
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

extension UIView {

    public func a11yMarkdown() -> String {
        let markers = accessibilityHierarchyParser.parseAccessibilityElements(in: self)
        return markers.map { $0.markdown }.joined(separator: "\n")
    }
}

extension AccessibilityMarker {

    var markdown: String {
        var string = self.description
        if string == "Heading." {
            string = "---"
        }
        if string.contains(". Button.") {
            string = "[\(string.replacingOccurrences(of: ". Button.", with: ""))]()"
        }
        if string.contains(". Image.") {
            string = string.replacingOccurrences(of: ". Image.", with: " 🌅")
        }
        if string.contains(". Heading.") {
            string = "\n#### \(string.replacingOccurrences(of: ". Heading.", with: ""))"
        } else {
            string = "- \(string)"
        }

        return string
    }
}

struct A11yPreviewProvider_Previews: PreviewProvider {
    static var previews: some View {
//        NavigationView {
            VStack {
                Text("My Title")
                    .font(.title)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityHeading(.h2)
                Text("Hello, world!")
                Picker("Option", selection: .constant(true)) {
                    Text("On").tag(true)
                    Text("Off").tag(false)
                }
                .pickerStyle(.segmented)
                Button("Login", action: {})
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("Close")
                    Image(systemName: "plus")
                }
            }
//        }
        .accessibilityPreview()
        .padding()
    }
}
#endif
