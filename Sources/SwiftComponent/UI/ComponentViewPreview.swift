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
    @AppStorage("componentPreview.viewMode") var viewMode: ViewMode = .device
    @AppStorage("componentPreview.deviceScale") var deviceScale: Scaling = Scaling.fit
    @AppStorage("componentPreview.showEnvironmentSelector") var showEnvironmentSelector = false

    enum ViewMode: String {
        case device
        case fill
        case fit
    }

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
                        contentView
#endif
                    } else {
                        switch viewMode {
                        case .device:
                            ScalingView(size: device.frameSize, scaling: deviceScale) {
                                contentView
                                    .embedIn(device: device)
                                    .previewColorScheme()
                                    .shadow(radius: 10)
                            }
                        case .fill:
                            contentView
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(.background)
                                .previewColorScheme()
                        case .fit:
                            contentView
                                .background(.background)
                                .previewColorScheme()
                                .cornerRadius(12)
                                .clipped()
                                .shadow(radius: 4)
                                .padding(16)
                                .frame(maxHeight: .infinity)
                        }
                    }
                }

                configBar(height: min(200, proxy.size.height/5))
            }
            .animation(.default, value: showEnvironmentSelector)
            .animation(.default, value: viewMode)
        }
#if os(iOS)
        .navigationViewStyle(StackNavigationViewStyle())
#endif
    }

    var contentView: some View {
        content
            .environment(\.sizeCategory, sizeCategory)
            .previewColorScheme()
    }

    var environmentPreview: some View {
        content
            .allowsHitTesting(false)
            .previewReference()
    }

    func configBar(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            Group {
                if #available(iOS 16.0, *) {
                    ViewThatFits {
                        HStack(spacing: 12) {
                            viewModeSelector
                            deviceControls
                            Spacer()
                            environmentToggle
                        }
                        VStack(alignment: .leading) {
                            HStack(spacing: 12) {
                                viewModeSelector
                                Spacer()
                                environmentToggle
                            }
                            if viewMode == .device {
                                deviceControls
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading) {
                        HStack(spacing: 12) {
                            viewModeSelector
                            Spacer()
                            environmentToggle
                        }
                        if viewMode == .device {
                            deviceControls
                        }
                    }
                }
            }
            .foregroundColor(.primary)
            .padding(.top)
            .padding(.horizontal)
            .buttonStyle(.plain)

            if showEnvironmentSelector {
                ScrollView(.horizontal) {
                    HStack(spacing: 40) {
                        colorSchemeSelector(height: height)
                        sizeCategorySelector(height: height)
                    }
                    .padding(.top)
                    .padding(.horizontal, 20)
                }
                .transition(.move(edge: .bottom))
            }
        }
        .background(systemColorScheme == .dark ? Color(white: 0.05) : Color(white: 0.95))
    }

    var environmentToggle: some View {
        Button(action: { showEnvironmentSelector.toggle() }) {
            Text("Environment")
            Image(systemName: "chevron.down")
        }
        .font(.subheadline)
        .buttonStyle(.bordered)
        .transformEffect(.identity) // fixes postion during animation https://stackoverflow.com/questions/70253645/swiftui-animate-view-transition-and-position-change-at-the-same-time/76094274#76094274
    }

    var viewModeSelector: some View {
        Picker(selection: $viewMode) {
            Text("Device")
                .tag(ViewMode.device)
            Text("Fill")
                .tag(ViewMode.fill)
            Text("Fit")
                .tag(ViewMode.fit)
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }

    var deviceControls: some View {
        HStack(spacing: 12) {
            Button {
                showDevicePicker = true
            } label: {
                HStack {
                    device.icon
                    Text(device.name)
                }
                .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .popover(isPresented: $showDevicePicker) {
                deviceSelector
                    .padding(20)
            }
            .disabled(viewMode != .device)
            .opacity(viewMode == .device ? 1 : 0)

            Picker(selection: $deviceScale) {
                Text("100%")
                    .tag(Scaling.exact)
                Text("Fit")
                    .tag(Scaling.fit)
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .disabled(viewMode != .device)
            .opacity(viewMode == .device ? 1 : 0)
        }
    }

    func sizeCategorySelector(height: CGFloat) -> some View {
        HStack(spacing: 12) {
            ForEach(sizeCategories, id: \.self) { size in
                Button(action: { withAnimation { sizeCategory = size } }) {
                    VStack(spacing: 8) {
                        Text(size.acronym)
                            .bold()
                            .lineLimit(1)
                        environmentPreview
                            .environment(\.sizeCategory, size)
                            .embedIn(device: device)
                            .previewColorScheme()
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

    func colorSchemeSelector(height: CGFloat) -> some View {
        HStack(spacing: 12) {
            ForEach(ColorScheme.allCases, id: \.self) { colorScheme in
                Button {
                    if PreviewColorScheme.current.colorScheme == colorScheme {
                        PreviewColorScheme.current = .system
                    } else {
                        PreviewColorScheme.current = .init(colorScheme: colorScheme)
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(colorScheme == .light ? "Light" : (colorScheme == .dark ? "Dark" : "Automatic"))
                            .bold()
                        environmentPreview
                            .environment(\.sizeCategory, sizeCategory)
                            .embedIn(device: device)
                            .colorScheme(colorScheme)
                            .scaleEffect(height / device.frameSize.height)
                            .frame(height: height)
                        Image(systemName: PreviewColorScheme.current.colorScheme == colorScheme ? "checkmark.circle.fill" : "circle")
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
                self.viewMode = .device
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

extension View {

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
//        NavigationView {
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
//        }
        .preview()
        .previewDevice(.largestDevice)
    }
}
