import Foundation
import SwiftUI
import SwiftPreview

struct ComponentViewPreview<Content: View>: View {
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
    @AppStorage("componentPreview.darkMode") var darkMode = false
    @AppStorage("componentPreview.inDevice") var inDevice = false
    @AppStorage("componentPreview.scale") var scaleString: String = Scaling.fit.rawValue
    @AppStorage("componentPreview.showEnvironmentSelector") var showEnvironmentSelector = false

    var scale: Binding<Scaling> {
        Binding<Scaling>(
            get: {
                .init(rawValue: scaleString) ?? .fit
            },
            set: {
                self.scaleString = $0.rawValue
            }
        )
    }
    var colorScheme: ColorScheme { darkMode ? .dark : .light }
    @Environment(\.colorScheme) var systemColorScheme: ColorScheme

    let content: Content
    let name: String?

    public init(content: Content, name: String? = nil) {
        self.content = content
        self.name = name
    }
    
    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    if let name {
                        Text(name)
                            .bold()
                            .font(.title2)
                            .padding(.bottom)
                    }
                    if showAccessibilityPreview {
#if canImport(UIKit)
                        content.accessibilityPreview()
#else
                        content
#endif
                    } else {
                        if inDevice {
                            ScalingView(size: device.frameSize, scaling: scale.wrappedValue) {
                                content
                                    .environment(\.sizeCategory, sizeCategory)
                                    .embedIn(device: device)
                                    .colorScheme(colorScheme)
                                    .shadow(radius: 10)
                            }
                        } else {
                            content
                                .environment(\.sizeCategory, sizeCategory)
                                .colorScheme(colorScheme)
                                .background(Color.white)
                                .background(.background)
                                .cornerRadius(12)
                                .padding(16)
                                .clipped()
                                .shadow(radius: 4)
                        }
                    }
                }
                Spacer()
                configBar(height: min(200, proxy.size.height/5))
            }
            .animation(.default, value: showEnvironmentSelector)
            .animation(.default, value: inDevice)
        }
#if os(iOS)
        .navigationViewStyle(StackNavigationViewStyle())
#endif
        .previewReference()
    }

    func configBar(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Button(action: { showEnvironmentSelector.toggle() }) {
                    Text("Environment")
                        .bold()
                        .font(.title2)
                    Image(systemName: "chevron.down")
                        .font(.title3)
                    Spacer()
                }
                if inDevice {
                    Button {
                        showDevicePicker = true
                    } label: {
                        Text(device.name)
                            .bold()
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showDevicePicker) {
                        deviceSelector
                            .padding(20)
                    }
                    Picker(selection: scale) {
                        Text("100%")
                            .tag(Scaling.exact)
                        Text("Fit")
                            .tag(Scaling.fit)
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }

                Picker(selection: $inDevice) {
                    Text("Device")
                        .tag(true)
                    Text("Fill View")
                        .tag(false)
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            .foregroundColor(.primary)
            .padding(.top)
            .padding(.horizontal)
            .buttonStyle(.plain)

            if showEnvironmentSelector {
                ScrollView(.horizontal) {
                    HStack(spacing: 40) {
                        sizeCategorySelector(height: height)
                        colorSchemeSelector(height: height)
                    }
                    .padding(.top)
                    .padding(.horizontal, 20)
                }
                .transition(.move(edge: .bottom))
            }
        }
        .background(Color(white: 0.95))
    }

    func sizeCategorySelector(height: CGFloat) -> some View {
        HStack(spacing: 12) {
            ForEach(sizeCategories, id: \.self) { size in
                Button(action: { withAnimation { sizeCategory = size } }) {
                    VStack(spacing: 8) {
                        Text(size.acronym)
                            .bold()
                            .lineLimit(1)
                        previewContent
                            .environment(\.sizeCategory, size)
                            .embedIn(device: device)
                            .colorScheme(colorScheme)
                            .scaleEffect(height / device.frameSize.height)
                            .frame(height: height)
                        Image(systemName: size == sizeCategory ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                    }
                    .frame(width: device.frameSize.width * (height / device.frameSize.height))
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

    func colorSchemeSelector(height: CGFloat) -> some View {
        HStack(spacing: 12) {
            ForEach(ColorScheme.allCases, id: \.self) { colorScheme in
                Button(action: { self.darkMode = colorScheme == .dark}) {
                    VStack(spacing: 8) {
                        Text(colorScheme == .light ? "Light" : (colorScheme == .dark ? "Dark" : "Automatic"))
                            .bold()
                        previewContent
                            .environment(\.sizeCategory, sizeCategory)
                            .embedIn(device: device)
                            .colorScheme(colorScheme)
                            .scaleEffect(height / device.frameSize.height)
                            .frame(height: height)
                        Image(systemName: self.colorScheme == colorScheme ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                    }
                    .frame(width: device.frameSize.width * (height / device.frameSize.height))
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
        Button {
            withAnimation {
                self.device = device
                self.inDevice = true
            }
        } label: {
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
        ComponentViewPreview(content: self, name: name)
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
