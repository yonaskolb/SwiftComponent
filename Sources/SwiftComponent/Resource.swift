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
        case loaded(State)
        case error(Error)

        public enum ResourceStateType {
            case loading
            case content
            case error
        }
    }

    /// order is the order that state type will be returned if it's not nil. States that are left out will be returned in the order content, loading, error
    public func state(order: [ResourceState.ResourceStateType] = [.content, .loading, .error]) -> ResourceState {
        for state in order {
            switch state {
                case .content:
                    if let content {
                        return .loaded(content)
                    }
                case .error:
                    if let error {
                        return .error(error)
                    }
                case .loading:
                    if isLoading {
                        return .loading
                    }
            }
        }

        // in case order is empty or doesn't contain all cases
        if let content {
            return .loaded(content)
        } else if isLoading {
            return .loading
        } else if let error {
            return .error(error)
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

extension Resource where State: Collection, State: ExpressibleByArrayLiteral {

    public var list: State {
        get {
            if let content {
                return content
            } else {
                return []
            }
        }
        set {
            content = newValue
        }
    }

    public static var empty: Self {
        self.content([])
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
        switch resource.state() {
        case .loaded(let value):
            content(value)
        case .error(let error):
            self.error(error)
        case .loading:
            ZStack {
                ProgressView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .unloaded:
            EmptyView()
        }
    }
}
