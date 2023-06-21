import Foundation
import SwiftUI

public struct ViewPreviewer<Content: View>: View {
    var sizeCategories: [ContentSizeCategory] = [
        .extraSmall,
        .large,
        .extraExtraExtraLarge,
        .accessibilityExtraExtraExtraLarge,
    ]

    var devices: [Device] = Device.all

    @State var sizeCategory: ContentSizeCategory = .large
    @State var buttonScale: CGFloat = 0.20
    @State var device = Device.iPhone14
    @State var showDevicePicker = false
    @State var showAccessibilityPreview = false
    @State var showEnvironmentPickers = false
    @AppStorage("componentPreview.darkMode") var darkMode = false
    var colorScheme: ColorScheme { darkMode ? .dark : .light }
    @Environment(\.colorScheme) var systemColorScheme: ColorScheme

    let content: Content
    let name: String?

    public init(content: Content, name: String? = nil, showEnvironmentPickers: Bool = true) {
        self.content = content
        self.name = name
        self._showEnvironmentPickers = .init(initialValue: showEnvironmentPickers)
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                if let name {
                    Text(name)
                        .bold()
                        .font(.title2)
                        .padding(.bottom)
                }
                Spacer()
                if showAccessibilityPreview {
#if canImport(UIKit)
                    content.accessibilityPreview()
#else
                    content
#endif
                } else {
                    content
                        .environment(\.sizeCategory, sizeCategory)
                        .embedIn(device: device)
                        .colorScheme(colorScheme)
                        .shadow(radius: 10)
                        .scaleEffect(device.contentScale)
                        .frame(width: device.frameSize.width*device.contentScale, height: device.frameSize.height*device.contentScale)
                        .padding()
                    Button {
                        showDevicePicker = true
                    } label: {
                        Text(device.name).bold().font(.title2)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showDevicePicker) {
                        deviceSelector
                            .padding(20)
                    }
                }
                Spacer()
            }
            Spacer()
            if showEnvironmentPickers {
                HStack(spacing: 40) {
                    sizeCategorySelector
                    colorSchemeSelector
                }
                .padding()
            }
        }
        #if os(iOS)
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }

    var sizeCategorySelector: some View {
        HStack(spacing: 12) {
            ForEach(sizeCategories, id: \.self) { size in
                Button(action: { withAnimation { sizeCategory = size } }) {
                    VStack(spacing: 8) {
                        Text(size.acronym)
                            .bold()
                        //                            .fontWeight(size == sizeCategory ? .bold : .regular)
                        //                            .font(.footnote)
                        //                            .foregroundColor(size == sizeCategory ? .accentColor : .primary)
                        previewContent
                            .environment(\.sizeCategory, size)
                            .embedIn(device: device)
                            .colorScheme(colorScheme)
                            .scaleEffect(buttonScale*device.contentScale)
                            .frame(height: device.height * buttonScale * device.contentScale)
                        Image(systemName: size == sizeCategory ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                        //                            .foregroundColor(.blue)
                    }
                    .frame(width: device.width * buttonScale * device.contentScale)
                }
                .buttonStyle(.plain)
            }
        }
    }

    var previewContent: some View {
        content
            .allowsHitTesting(false)
            .previewReference()
    }

    var colorSchemeSelector: some View {
        HStack(spacing: 12) {
            ForEach(ColorScheme.allCases, id: \.self) { colorScheme in
                Button(action: { self.darkMode = colorScheme == .dark}) {
                    VStack(spacing: 8) {
                        Text(colorScheme == .light ? "Light" : (colorScheme == .dark ? "Dark" : "Automatic"))
                            .bold()
                        //                            .font(.footnote)
                        previewContent
                            .environment(\.sizeCategory, sizeCategory)
                            .embedIn(device: device)
                            .colorScheme(colorScheme)
                            .scaleEffect(buttonScale*device.contentScale)
                            .frame(height: device.height * buttonScale * device.contentScale)
                        Image(systemName: self.colorScheme == colorScheme ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                        //                            .foregroundColor(.blue)
                    }
                    .frame(width: device.width * buttonScale * device.contentScale)
                }
                .buttonStyle(.plain)
            }
        }
    }

    var deviceSelector: some View {
        VStack(spacing: 40) {
            HStack {
                ForEach(Device.iPhones, id: \.name, content: deviceView)
            }
            HStack {
                ForEach(Device.iPads, id: \.name, content: deviceView)
            }
        }
        .foregroundColor(.accentColor)
    }

    func deviceView(_ device: Device) -> some View {
        Button(action: { withAnimation { self.device = device } }) {
            VStack(spacing: 2) {
                device.icon
                    .font(.system(size: 100, weight: .ultraLight))
                //.scaleEffect(device.scale * device.contentScale, anchor: .bottom)
                var nameParts = device.name.components(separatedBy: " ")
                let deviceType = nameParts.removeFirst()
                let name = "\(deviceType)\n\(nameParts.joined(separator: " "))"
                Text(name)
                    .bold()
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                Image(systemName: self.device == device ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30))
                    .padding(.top, 2)
            }
        }
        .buttonStyle(.plain)
    }
}

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

    public func preview(name: String? = nil) -> some View {
        ViewPreviewer(content: self, name: name)
    }
}

extension ContentSizeCategory {

    var acronym: String {
        switch self {
            case .extraSmall:
                return "XS"
            case .small:
                return "S"
            case .medium:
                return "M"
            case .large:
                return "L"
            case .extraLarge:
                return "XL"
            case .extraExtraLarge:
                return "XXL"
            case .extraExtraExtraLarge:
                return "XXXL"
            case .accessibilityMedium:
                return "AM"
            case .accessibilityLarge:
                return "AL"
            case .accessibilityExtraLarge:
                return "AXL"
            case .accessibilityExtraExtraLarge:
                return "AXXL"
            case .accessibilityExtraExtraExtraLarge:
                return "AXXXL"
            @unknown default:
                return ""
        }
    }
}

struct ViewPreviewer_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VStack {
                Text("🌻")
                    .font(.system(size: 100))
                Text("Hello, world")
                    .font(.title2)
            }
            .navigationTitle(Text("My App"))
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Image(systemName: "plus")
                }
            }
        }
        .preview()
        .previewDevice(.largestDevice)
    }
}
