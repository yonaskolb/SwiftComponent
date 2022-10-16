//
//  File.swift
//  
//
//  Created by Yonas Kolb on 14/9/2022.
//

import Foundation
import SwiftUI

enum ComponentViewMode: String, Identifiable {
    case view
    case data
    case history

    var id: String { rawValue }
}

public struct PresentedRoute<Route> {
    public var route: Route
    public var mode: PresentationMode
    var inNav: Bool
    var component: AnyView
}

public enum PresentationMode {
    case sheet
    case push
}

extension ComponentView {

    func routing<V: View>(route: (C.Route) -> V) -> some View {
        //TODO: do routing
        EmptyView()
    }
}
