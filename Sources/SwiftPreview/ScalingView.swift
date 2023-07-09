import Foundation
import SwiftUI

struct ScalingView<Content: View>: View {
    let size: CGSize
    let scaling: Scaling = .fit
    var content: () -> Content

    enum Scaling {
        case actual
        case fit
    }

    func scale(frame: CGSize) -> CGFloat {
        min(frame.height / size.height, frame.width / size.width)
    }

    var body: some View {
        switch scaling {
        case .actual:
            ScrollView {
                content()
                    .padding()
                    .frame(maxWidth: .infinity)
            }
        case .fit:
            GeometryReader { proxy in
                content()
                    .scaleEffect(scale(frame: proxy.size))
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .padding()
        }
    }
}
