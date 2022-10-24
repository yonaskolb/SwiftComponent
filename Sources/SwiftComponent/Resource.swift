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

    public init(content: State? = nil, error: Error? = nil, isLoading: Bool = false) {
        self.content = content
        self.error = error
        self.isLoading = isLoading
    }

    public enum ResourceState {
        case unloaded
        case loading
        case content(State)
        case error(Error)
    }

    /// content takes precedence over error if both are non nil
    public var state: ResourceState {
        if let content {
            return .content(content)
        } else if let error = error {
            return .error(error)
        } else if isLoading {
            return .loading
        } else {
            return .unloaded
        }
    }
}

public extension Resource {
    static var unloaded: Self { Resource(content: nil, error: nil, isLoading: false) }
    static var loading: Self { Resource(content: nil, error: nil, isLoading: true) }
    static func content<C>(_ content: C) -> Resource<C> { Resource<C>(content: content, error: nil, isLoading: false) }
    static func error(_ error: Error) -> Resource { Resource(content: nil, error: error, isLoading: false) }
}

extension Resource: Equatable where State: Equatable {
    public static func == (lhs: Resource<State>, rhs: Resource<State>) -> Bool {
        lhs.content == rhs.content && lhs.isLoading == rhs.isLoading && lhs.error?.localizedDescription == rhs.error?.localizedDescription
    }
}

/// A simple view for visualizing a Resource. If you want custom UI for loading and unloaded states, use a custom view and switch over Resource.state or access it's other properties directly
public struct ResourceView<State: Equatable, Content: View, ErrorView: View>: View {

    let resource: Resource<State>
    let content: (State) -> Content
    let error: (Error) -> ErrorView

    public init(_ resource: Resource<State>, @ViewBuilder content: @escaping (State) -> Content, @ViewBuilder error: @escaping (Error) -> ErrorView) {
        self.resource = resource
        self.content = content
        self.error = error
    }

    public var body: some View {
        switch resource.state {
            case .content(let value):
                content(value)
            case .error(let error):
                self.error(error)
            case .loading:
                ProgressView()
            case .unloaded:
                EmptyView()
        }
    }
}
