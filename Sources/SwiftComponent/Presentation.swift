import Foundation
import SwiftUI

//TODO: turn into protocol that handles any sort of presentation based on view modifiers
public enum Presentation {
    case sheet
    case push
    case fullScreenCover

    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    // use NavigationView instead of NavigationStack for push presentations on iOS 16.
    public static var useNavigationViewOniOS16 = false
}

// wip
//public protocol PresentationType<Destination> {
//
//    associatedtype PresentationView: View
//    associatedtype Destination
//    associatedtype DestinationView: View
//    func attach<V: View>(_ view: V, destination: Binding<Destination?>, destinationView: (Destination) -> DestinationView) -> Self.PresentationView
//}
//
//public struct SheetPresentation<D, DV: View>: PresentationType {
//    public typealias Destination = D
//    public typealias DestinationView = DV
//    var destination: Binding<Destination?>
//    var destinationView: (Destination) -> DV
//
//    public func attach<V: View>(_ view: V, destination: Binding<Destination?>, destinationView: (Destination) -> DestinationView) -> some View {
//        view.sheet(isPresented: Binding(get: { destination.wrappedValue != nil}, set: { if !$0 { destination.wrappedValue = nil }})) {
//            if let destination = destination.wrappedValue {
//                destinationView(destination)
//            }
//        }
//    }
//}
