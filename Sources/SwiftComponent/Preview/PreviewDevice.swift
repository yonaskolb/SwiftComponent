//
//  File.swift
//  
//
//  Created by Yonas Kolb on 18/10/2022.
//

import Foundation
import SwiftUI

public struct ViewPreviewer<Content: View>: View {
    var sizeCategories: [ContentSizeCategory] = [
        .small,
        .large,
        .extraExtraExtraLarge,
        .accessibilityMedium,
        .accessibilityExtraExtraExtraLarge,
    ]

    var devices: [Device] = [
        .iPhoneSE,
        .iPhone12Mini,
        .iPhone12ProMax,
        .iPad11Pro,
    ]

    @State var sizeCategory: ContentSizeCategory = .large
    @State var buttonScale: CGFloat = 0.15
    @State var device = Device.iPhone12Mini

    let content: Content
    let name: String

    public init(content: Content, name: String? = nil) {
        self.content = content
        self.name = name ?? String(describing: type(of: content))
    }

    public var body: some View {
        VStack(spacing: 10.0) {
            VStack(spacing: 0) {
                Text(name)
                    .bold()
                    .padding(.bottom)
                content
                    .frame(width: device.size.width, height: device.size.height)
                    .environment(\.sizeCategory, sizeCategory)
                    .device()
                    .scaleEffect(device.contentScale)
                    .frame(width: device.size.width*device.contentScale, height: device.size.height*device.contentScale)
            }
            Spacer()
            sizeCategorySelector
                .padding(.bottom, 20)
            deviceSelector
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .previewDevice("iPad Pro (12.9-inch) (4th generation)")
    }

    var sizeCategorySelector: some View {
        HStack {
            ForEach(sizeCategories, id: \.self) { size in
                Button(action: { withAnimation { sizeCategory = size } }) {
                    VStack {
                        Text(String(describing: size))
                            .font(.footnote)
                            .bold()
                        content
                            .allowsHitTesting(false)
                            .frame(width: device.size.width, height: device.size.height)
                            .environment(\.sizeCategory, size)
                            .device()
                            .scaleEffect(buttonScale*device.contentScale)
                            .frame(width: device.size.width * buttonScale * device.contentScale, height: device.size.height * buttonScale * device.contentScale)
                        Image(systemName: size == sizeCategory ? "checkmark.circle.fill" : "circle")
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    var deviceSelector: some View {
        HStack {
            ForEach(devices, id: \.rawValue) { device in
                Button(action: { withAnimation { self.device = device } }) {
                    VStack {
                        device.image
                            .font(.system(size: 70, weight: .ultraLight))
                            .scaleEffect(device.scale * device.contentScale, anchor: .bottom)
                        Text(String(describing: device.shortName))
                            .bold()
                            .font(.footnote)
                        Image(systemName: self.device == device ? "checkmark.circle.fill" : "circle")
                    }
                }
            }
        }
    }
}

private extension View {

    func device() -> some View {
        self
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 10)
            .padding()
    }
}

extension View {

    public func preview() -> some View {
        ViewPreviewer(content: self)
    }
}

public enum Device: String {
    case iPhoneSE = "iPhone SE (1st generation)"
    case iPhone11 = "iPhone 11"
    case iPhone12Mini = "iPhone 12 mini"
    case iPhone12 = "iPhone 12"
    case iPhone12ProMax = "iPhone 12 Pro Max"
    case iPad11Pro = "iPad Pro (11-inch) (3rd generation)"
}

extension Device {

    var size: CGSize {
        switch self {
        case .iPhoneSE: return CGSize(width: 320, height: 568)
        case .iPhone11: return CGSize(width: 414, height: 896)
        case .iPhone12Mini: return CGSize(width: 360, height: 780)
        case .iPhone12: return CGSize(width: 390, height: 844)
        case .iPhone12ProMax: return CGSize(width: 428, height: 926)
        case .iPad11Pro: return CGSize(width: 834, height: 1194)
        }
    }

    var scale: CGFloat {
        size.width/Device.iPhone11.size.width
    }

    var contentScale: CGFloat {
        switch self {
        case .iPhoneSE: return 1
        case .iPhone11: return 1
        case .iPhone12Mini: return 1
        case .iPhone12: return 1
        case .iPhone12ProMax: return 1
        case .iPad11Pro: return 0.7
        }
    }

    var shortName: String {
        rawValue
            .replacingOccurrences(of: "iPhone ", with: "")
            .replacingOccurrences(of: "(1st generation)", with: "")
            .replacingOccurrences(of: "(3rd generation)", with: "")
            .replacingOccurrences(of: "Pro ", with: "")
            .replacingOccurrences(of: "Max", with: "max")
    }

    var image: Image {
        if #available(iOS 14.0, *) {
            switch self {
            case .iPhoneSE: return Image(systemName: "iphone.homebutton")
            case .iPhone11: return Image(systemName: "iphone")
            case .iPhone12Mini: return Image(systemName: "iphone")
            case .iPhone12: return Image(systemName: "iphone")
            case .iPhone12ProMax: return Image(systemName: "iphone")
            case .iPad11Pro: return Image(systemName: "ipad")
            }
        } else {
            return Image(systemName: "square")
        }
    }
}
