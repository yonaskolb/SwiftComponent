//
//  File.swift
//  
//
//  Created by Yonas Kolb on 19/10/2022.
//

import Foundation
import SwiftUI

struct Device: Equatable {
    var name: String
    var type: DeviceType
    var width: Double
    var height: Double
    var icon: Icon {
        switch (homeIndicator, type) {
            case (true, .iPad): return .iPad
            case (false, .iPad): return .iPadHome
            case (true, .iPhone): return .iPhone
            case (false, .iPhone): return .iPhoneHome
        }
    }
    //TODO: edit these for different devices
    var bezelWidth: Double = 14
    var topSafeAreaHeight: Double = 47
    var bottomSafeAreaHeight: Double = 34
    var homeIndicator: Bool
    var notch: Bool

    var frameSize: CGSize {
        CGSize(width: width + bezelWidth*2, height: height + bezelWidth*2)
    }
    
    var contentScale: Double {
        (icon == .iPad || icon == .iPadHome) ? 0.5 : 1
    }
    
    var scale: CGFloat {
        width/Device.iPhone14.width
    }
    
    static let iPhoneSE = Device.iPhone(name: "iPhone SE", width: 320, height: 568, homeIndicator: false, notch: false)
    static let iPhone13Mini = Device.iPhone(name: "iPhone 13 Mini", width: 375, height: 812)
    static let iPhone14 = Device.iPhone(name: "iPhone 14", width: 390, height: 844)
    static let iPhone14Plus = Device.iPhone(name: "iPhone 14 Plus", width: 428, height: 926)
    static let iPhone14Pro = Device.iPhone(name: "iPhone 14 Pro", width: 393, height: 852)
    static let iPhone14ProMax = Device.iPhone(name: "iPhone 14 Pro Max", width: 430, height: 932)
    
    static let iPadAir = Device.iPad(name: "iPad Air", width: 820, height: 1180)
    static let iPadMini = Device.iPad(name: "iPad Mini", width: 744, height: 1133)
    static let iPad = Device.iPad(name: "iPad", width: 810, height: 1080)
    static let iPadPro12 = Device.iPad(name: "iPad Pro 12.9\"", width: 1024, height: 1366)
    static let iPadPro11 = Device.iPad(name: "iPad Pro 11\"", width: 834, height: 1194)
    
    static func iPhone(name: String, width: Double, height: Double, homeIndicator: Bool = true, notch: Bool = true) -> Device {
        Device(name: name, type: .iPhone, width: width, height: height, homeIndicator: homeIndicator, notch: notch)
    }

    static func iPad(name: String, width: Double, height: Double, homeIndicator: Bool = true) -> Device {
        Device(name: name, type: .iPad, width: width, height: height, bottomSafeAreaHeight: homeIndicator ? 34 : 0, homeIndicator: homeIndicator, notch: false)
    }

    static let iPhones: [Device] = [
        iPhoneSE,
        iPhone13Mini,
        iPhone14,
        iPhone14Plus,
        iPhone14Pro,
        iPhone14ProMax,
    ]

    static let iPads: [Device] = [
        iPadAir,
        iPadMini,
//        iPad,
        iPadPro12,
        iPadPro11,
    ]

    static let all: [Device] = iPhones + iPads

    enum DeviceType: String {
        case iPhone = "iPhone"
        case iPad = "iPad"
    }

    enum Icon: String {
        case iPhone = "iphone"
        case iPhoneHome = "iphone.homebutton"
        case iPad = "ipad"
        case iPadHome = "ipad.homebutton"
    }

    var image: Image {
        Image(systemName: icon.rawValue)
    }
}

extension PreviewDevice {

    static var iPadLargest: PreviewDevice {
        PreviewDevice(rawValue: "iPad Pro (12.9-inch) (5th generation)")
    }
}

extension View {

    func embedIn(device: Device) -> some View {
        self.modifier(PhoneModifier(device: device))
    }
}

struct PhoneModifier: ViewModifier {
    var device: Device
    var frameColor = Color(white: 0.05)
    var notchHeight: CGFloat = 34
    var notchTopRadius: CGFloat = 8

    /// works for regular content, except navigation bars
    var useTopSafeArea = false

    var deviceShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 40, style: .continuous)
    }

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            if !useTopSafeArea {

                topBar
                    .frame(height: device.topSafeAreaHeight)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if useTopSafeArea {
                topBar
                .frame(height: device.topSafeAreaHeight)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if device.homeIndicator {
                    homeIndicator
                }
            }
            .frame(height: device.bottomSafeAreaHeight, alignment: .bottom)
        }
        .frame(width: device.width, height: device.height)
        .background(.background)
        .overlay {
            deviceShape
                .inset(by: -device.bezelWidth/2)
                .stroke(frameColor, lineWidth: device.bezelWidth)
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
                    Color.gray
                    Text("iPhone")
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
        .previewDevice(.iPadLargest)
    }
}
