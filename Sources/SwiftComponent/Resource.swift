//
//  File.swift
//  
//
//  Created by Yonas Kolb on 14/9/2022.
//

import Foundation
import SwiftUI

public struct Resource<State> {
    public var content: State?
    public var error: Error?
    public var isLoading: Bool = false
}

public extension Resource {
    static var empty: Self { Resource(content: nil, error: nil, isLoading: false) }
}

struct ResourceView<State, Content: View>: View {

    let resource: Resource<State>
    let content: (State) -> Content

    init(_ resource: Resource<State>, content: @escaping (State) -> Content) {
        self.resource = resource
        self.content = content
    }

    var body: some View {
        if let content = resource.content {
            self.content(content)
        } else if let error = resource.error {
            Text(error.localizedDescription)
        } else if resource.isLoading {
            ProgressView()
        }
    }
}
