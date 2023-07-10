import Foundation
import SwiftUI

extension View {

    public func embedIn(device: Device) -> some View {
        self.modifier(DeviceWrapper(device: device))
    }
}

struct DeviceWrapper: ViewModifier {
    var device: Device
    var frameColor = Color(white: 0.05)
    var borderColor = Color(white: 0.15)
    var notchHeight: CGFloat = 34
    var notchTopRadius: CGFloat = 8

    /*
     NavigationView resets any safe area insets.
     This means any content that is within a NavigationView won't be inset correctly.
     A workaround is to push content in but that breaks content content that ignores the safe area like a fullbleed background.
     */
    var insetUsingSafeArea = false

    var deviceShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 40, style: .continuous)
    }

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            if !insetUsingSafeArea {
                topBar
                    .frame(height: device.topSafeAreaHeight)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if !insetUsingSafeArea {
                Group {
                    if device.homeIndicator {
                        homeIndicator
                    }
                }
                .frame(height: device.bottomSafeAreaHeight, alignment: .bottom)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if insetUsingSafeArea {
                topBar
                .frame(height: device.topSafeAreaHeight)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if insetUsingSafeArea {
                Group {
                    if device.homeIndicator {
                        homeIndicator
                    }
                }
                .frame(height: device.bottomSafeAreaHeight, alignment: .bottom)
            }
        }
        .frame(width: device.width, height: device.height)
        .background(.background)
        .overlay {
            deviceShape
                .inset(by: -device.bezelWidth/2)
                .stroke(frameColor, lineWidth: device.bezelWidth)
            deviceShape
                .inset(by: -device.bezelWidth)
                .stroke(borderColor, lineWidth: 2)
        }
        .clipShape(deviceShape.inset(by: -device.bezelWidth))
        .padding(device.bezelWidth)
    }

    var topBar: some View {
        HStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                //                Text(context.date, format: Date.FormatStyle(date: .none, time: .shortened))
                Text("9:41 AM")
                    .fontWeight(.medium)
                    .padding(.leading, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if device.notch {
                notch
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            HStack {
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
            }
            .padding(.trailing, 24)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    var notch: some View {
        let topCorner = CornerShape(cornerRadius: notchTopRadius)
            .fill(frameColor, style: .init(eoFill: true))
            .frame(width: notchTopRadius*2, height: notchTopRadius*2)
            .frame(width: notchTopRadius, height: notchTopRadius, alignment: .topTrailing)
            .clipped()

        return HStack(alignment: .top, spacing: 0) {
            topCorner
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(frameColor)
                .frame(height: notchHeight*2)
                .frame(width: 162, height: notchHeight, alignment: .bottom)
            topCorner
                .scaleEffect(x: -1)
        }
    }

    var homeIndicator: some View {
        Capsule(style: .continuous)
            .frame(width: 160, height: 5)
            .frame(height: 13, alignment: .top)
    }
}

struct CornerShape: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { p in
            p.addRoundedRect(in: rect, cornerSize: .init(width: cornerRadius, height: cornerRadius), style: .continuous)
            p.addRect(rect)
        }
    }
}

struct Device_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                ZStack {
                    Color.blue
                    VStack {
                        Spacer()
                        Text("iPhone")
                        Spacer()
                        Text("Bottom")
                            .padding(.bottom, 8)
                    }
                }
                .navigationTitle(Text("Title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Image(systemName: "plus")
                    }
                }
            }
            .embedIn(device: .iPhone14Pro)
            ZStack {
                Color.gray
                Text("iPad")
            }
            .embedIn(device: .iPadPro12)
        }
        .navigationViewStyle(.stack)
        .previewLayout(.sizeThatFits)
        .previewDevice(.largestDevice)
    }
}
