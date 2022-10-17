//
//  ExampleApp.swift
//  Example
//
//  Created by Yonas Kolb on 1/10/2022.
//

import SwiftUI

@main
struct ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ItemView(store: .init(state: .init(name: "Bob", data: .empty)))
        }
    }
}
