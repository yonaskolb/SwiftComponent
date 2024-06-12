
import Foundation
import SwiftUI

extension View {
    
    public func largePreview() -> some View {
        self.previewDevice(.iPad)
    }
}
