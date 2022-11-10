import Foundation
import SwiftUI

//TODO: turn into protocol that handles any sort of presentation based on view modifiers
public enum Presentation {
    case sheet
    case push
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
