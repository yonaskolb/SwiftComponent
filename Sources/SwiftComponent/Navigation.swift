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
    case actions

    var id: String { rawValue }
}

public struct PresentedRoute<Route> {
    var route: Route
    var mode: PresentationMode
    var inNav: Bool
    var component: AnyView
}

public enum PresentationMode {
    case sheet
    case push
}
