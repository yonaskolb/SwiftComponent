import Foundation
import SwiftUI

public enum Scaling: String {
    case exact
    case fit
}

public struct ScalingView<Content: View>: View {
    let size: CGSize
    let scaling: Scaling
    var content: Content

    public init(size: CGSize, scaling: Scaling = .fit, @ViewBuilder content: () -> Content) {
        self.size = size
        self.scaling = scaling
        self.content = content()
    }

    func scale(frame: CGSize) -> CGFloat {
        min(frame.height / size.height, frame.width / size.width)
    }

    public var body: some View {
        switch scaling {
        case .exact:
            ScrollView {
                content
                    .padding()
                    .frame(maxWidth: .infinity)
            }
        case .fit:
            GeometryReader { proxy in
                content
                    .scaleEffect(scale(frame: proxy.size))
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .padding()
        }
    }
}
