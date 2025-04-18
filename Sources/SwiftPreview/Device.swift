import Foundation
import SwiftUI

public struct Device: Equatable {
    public var name: String
    public var type: DeviceType
    public var width: Double
    public var height: Double
    var iconType: Icon {
        switch (homeIndicator, type) {
        case (true, .iPad): return .iPad
        case (false, .iPad): return .iPadHome
        case (true, .iPhone): return .iPhone
        case (false, .iPhone): return .iPhoneHome
        case (_, .custom): return .custom
        }
    }
    //TODO: edit these for different devices
    var bezelWidth: Double = 14
    var topSafeAreaHeight: Double = 47
    var bottomSafeAreaHeight: Double = 34
    var homeIndicator: Bool
    var notch: Bool
    var statusBar: Bool = true

    public var frameSize: CGSize {
        CGSize(width: width + bezelWidth*2, height: height + bezelWidth*2)
    }

    public static let smallPhone = Device(name: "small", type: .custom, width: 320, height: 600, homeIndicator: false, notch: false, statusBar: false)
    public static let mediumPhone = Device(name: "medium", type: .custom, width: 375, height: 812, homeIndicator: false, notch: false, statusBar: false)
    public static let largePhone = Device(name: "large", type: .custom, width: 430, height: 932, homeIndicator: false, notch: false, statusBar: false)
    public static let phone = Device(name: "phone", type: .custom, width: 375, height: 812, homeIndicator: false, notch: false, statusBar: false)

    public static let iPhoneSE = Device.iPhone(name: "iPhone SE", width: 320, height: 568, homeIndicator: false, notch: false)
    public static let iPhone13Mini = Device.iPhone(name: "iPhone 13 Mini", width: 375, height: 812)
    public static let iPhone14 = Device.iPhone(name: "iPhone 14", width: 390, height: 844)
    public static let iPhone14Plus = Device.iPhone(name: "iPhone 14 Plus", width: 428, height: 926)
    public static let iPhone14Pro = Device.iPhone(name: "iPhone 14 Pro", width: 393, height: 852)
    public static let iPhone14ProMax = Device.iPhone(name: "iPhone 14 Pro Max", width: 430, height: 932)

    public static let iPadAir = Device.iPad(name: "iPad Air", width: 820, height: 1180)
    public static let iPadMini = Device.iPad(name: "iPad Mini", width: 744, height: 1133)
    public static let iPad = Device.iPad(name: "iPad", width: 810, height: 1080)
    public static let iPadPro12 = Device.iPad(name: "iPad Pro 12.9\"", width: 1024, height: 1366)
    public static let iPadPro11 = Device.iPad(name: "iPad Pro 11\"", width: 834, height: 1194)

    public static func iPhone(name: String, width: Double, height: Double, homeIndicator: Bool = true, notch: Bool = true) -> Device {
        Device(name: name, type: .iPhone, width: width, height: height, homeIndicator: homeIndicator, notch: notch)
    }

    public static func iPad(name: String, width: Double, height: Double, homeIndicator: Bool = true) -> Device {
        Device(name: name, type: .iPad, width: width, height: height, bottomSafeAreaHeight: homeIndicator ? 34 : 0, homeIndicator: homeIndicator, notch: false)
    }

    public static let iPhones: [Device] = [
        iPhoneSE,
        iPhone13Mini,
        iPhone14,
        iPhone14Plus,
        iPhone14Pro,
        iPhone14ProMax,
    ]

    public static let iPads: [Device] = [
        iPadMini,
        iPadAir,
        iPad,
        iPadPro11,
        iPadPro12,
    ]

    public static let all: [Device] = iPhones + iPads

    public enum DeviceType: String {
        case iPhone = "iPhone"
        case iPad = "iPad"
        case custom = "Custom"
    }

    enum Icon: String {
        case iPhone = "iphone"
        case iPhoneHome = "iphone.homebutton"
        case iPad = "ipad"
        case iPadHome = "ipad.homebutton"
        case custom = "rectangle.dashed"
    }

    public var icon: Image {
        Image(systemName: iconType.rawValue)
    }
}

extension PreviewDevice {

    public static var iPad: PreviewDevice {
        PreviewDevice(rawValue: "iPad Pro 11-inch (M4)")
    }
}
