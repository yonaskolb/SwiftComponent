#if os(iOS)
import Foundation
import SwiftUI
import AccessibilitySnapshotCore
import UIKit

extension View {

    public func accessibilityPreview() -> some View {
        let hierarchy = self.accessibilityHierarchy()
        return AccessibilityHierarchyView(hierarchy: hierarchy)
    }
}

struct AccessibilityHierarchyView: View {

    let hierarchy: AccessibilityHierarchy

    var body: some View {
        if hierarchy.isEmpty {
            Text("Accessibility hierarchy not found")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(hierarchy.enumerated()), id: \.offset) { index, marker in
                        HStack {
                            markerView(marker)
                            Spacer()
                        }

                    }
                }
                .padding()
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
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                case .heading:
                Text(type.content)
                    .bold()
                    .font(.title2)
                    .padding(.bottom, 8)
                case .image:
                HStack {
                    Image(systemName: "photo")
                    Text(type.content)
                }
            }
        } else {
            Text(marker.description)
        }
    }
}

struct AccessibilityExampleView: View {

    var body: some View {
        NavigationView {
            VStack {
                Text("My Title")
                    .font(.title)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityHeading(.h2)
                Text("Hello, world!")
                Toggle("Toggle", isOn: .constant(true))
                Image(systemName: "person")
                Picker("Option", selection: .constant(true)) {
                    Text("On").tag(true)
                    Text("Off").tag(false)
                }
                .pickerStyle(.segmented)
                Text("Some really long text. Some really long text. Some really long text. Some really long text. Some really long text. ")
                Button("Login", action: {})
            }
            .navigationTitle(Text("Nav title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("Close")
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct A11yPreviewProvider_Previews: PreviewProvider {
    static var previews: some View {
        AccessibilityExampleView().accessibilityPreview()
    }
}
#endif
