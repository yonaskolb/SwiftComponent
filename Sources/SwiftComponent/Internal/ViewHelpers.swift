import Foundation
import SwiftUI

extension View {

    func interactiveBackground() -> some View {
        contentShape(Rectangle())
    }

    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}
