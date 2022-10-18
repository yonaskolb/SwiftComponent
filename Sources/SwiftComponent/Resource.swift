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
    static var loading: Self { Resource(content: nil, error: nil, isLoading: true) }
    static func content<C>(_ content: C) -> Resource<C> { Resource<C>(content: content, error: nil, isLoading: false) }
    static func error(_ error: Error) -> Resource { Resource(content: nil, error: error, isLoading: false) }
}

extension Resource: Equatable where State: Equatable {
    public static func == (lhs: Resource<State>, rhs: Resource<State>) -> Bool {
        lhs.content == rhs.content && lhs.isLoading == rhs.isLoading && lhs.error?.localizedDescription == rhs.error?.localizedDescription
    }
}

public struct ResourceView<State, Content: View>: View {

    let resource: Resource<State>
    let content: (State) -> Content

    public init(_ resource: Resource<State>, content: @escaping (State) -> Content) {
        self.resource = resource
        self.content = content
    }

    public var body: some View {
        if let content = resource.content {
            self.content(content)
        } else if let error = resource.error {
            Text(error.localizedDescription)
        } else if resource.isLoading {
            ProgressView()
        }
    }
}
