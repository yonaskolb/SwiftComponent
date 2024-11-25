import Foundation
import SwiftUI
import Perception

@propertyWrapper
public struct ResourceState<Value> {
    public var wrappedValue: Value? {
        get { content }
        set { content = newValue }
    }
    public var content: Value?
    public var error: Error?
    public var isLoading: Bool = false

    public init(wrappedValue: Value?) {
        self.wrappedValue = wrappedValue
    }

    public init(content: Value? = nil, error: Error? = nil, isLoading: Bool = false) {
        self.content = content
        self.error = error
        self.isLoading = isLoading
    }

    public enum State {
        case unloaded
        case loading
        case loaded(Value)
        case error(Error)

        public enum ResourceStateType {
            case loading
            case content
            case error
        }
    }

    /// order is the order that state type will be returned if it's not nil. States that are left out will be returned in the order content, loading, error
    public func state(order: [State.ResourceStateType] = [.content, .loading, .error]) -> State {
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
    
    public var projectedValue: ResourceState { 
        get {
            return self
        }
        set {
            self = newValue
        }
    }
}

public extension ResourceState {
    static var unloaded: ResourceState { ResourceState(content: nil, error: nil, isLoading: false) }
    static var loading: ResourceState { ResourceState(content: nil, error: nil, isLoading: true) }
    static func content<C>(_ content: C) -> ResourceState<C> { ResourceState<C>(content: content, error: nil, isLoading: false) }
    static func error(_ error: Error) -> ResourceState { ResourceState(content: nil, error: error, isLoading: false) }
}

extension ResourceState: Equatable where Value: Equatable {
    public static func == (lhs: ResourceState<Value>, rhs: ResourceState<Value>) -> Bool {
        lhs.content == rhs.content && lhs.isLoading == rhs.isLoading && lhs.error?.localizedDescription == rhs.error?.localizedDescription
    }
}

extension ResourceState: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(content)
        hasher.combine(isLoading)
        hasher.combine(error?.localizedDescription)
    }
}

extension ResourceState where Value: Collection, Value: ExpressibleByArrayLiteral {

    public var list: Value {
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

    public static var empty: ResourceState {
        self.content([])
    }
}

extension ResourceState {

    public func map<T>(_ map: (Value) -> T) -> ResourceState<T> {
        ResourceState<T>(content: content.map(map), error: error, isLoading: isLoading)
    }
}

func getResourceTaskName<State, R>(_ keyPath: KeyPath<State, ResourceState<R>>) -> String {
    "load \(keyPath.propertyName ?? "resource")"
}

extension ComponentModel {

    @MainActor
    public func loadResource<S>(_ keyPath: WritableKeyPath<State, ResourceState<S>>, animation: Animation? = nil, overwriteContent: Bool = true, file: StaticString = #filePath, line: UInt = #line, load: @MainActor @escaping () async throws -> S) async {
        mutate(keyPath.appending(path: \.isLoading), true, animation: animation)
        let name = getResourceTaskName(keyPath)
        await store.task(name, cancellable: true, source: .capture(file: file, line: line)) { @MainActor in
            let content = try await load()
            self.mutate(keyPath.appending(path: \.content), content, animation: animation)
            if self.store.state[keyPath: keyPath.appending(path: \.error)] != nil {
                self.mutate(keyPath.appending(path: \.error), nil, animation: animation)
            }
            return content
        } catch: { error in
            if overwriteContent, store.state[keyPath: keyPath.appending(path: \.content)] != nil {
                mutate(keyPath.appending(path: \.content), nil, animation: animation)
            }
            mutate(keyPath.appending(path: \.error), error, animation: animation)
        }
        mutate(keyPath.appending(path: \.isLoading), false, animation: animation)
    }
}

/// A simple view for visualizing a Resource. If you want custom UI for loading and unloaded states, use a custom view and switch over Resource.state or access it's other properties directly
public struct ResourceView<Value: Equatable, Content: View, ErrorView: View, LoadingView: View>: View {

    // the order of states if they are not nil. States that are left out will be returned in the order content, loading, error
    let stateOrder: [ResourceState<Value>.State.ResourceStateType]
    let resource: ResourceState<Value>
    let content: (Value) -> Content
    let loading: () -> LoadingView
    let error: (Error) -> ErrorView

    public init(_ resource: ResourceState<Value>,
                stateOrder: [ResourceState<Value>.State.ResourceStateType] = [.content, .loading, .error],
                @ViewBuilder loading:@escaping () -> LoadingView,
                @ViewBuilder content: @escaping (Value) -> Content,
                @ViewBuilder error: @escaping (Error) -> ErrorView) {
        self.resource = resource
        self.stateOrder = stateOrder
        self.loading = loading
        self.content = content
        self.error = error
    }
    
    public init(_ resource: ResourceState<Value>,
                stateOrder: [ResourceState<Value>.State.ResourceStateType] = [.content, .loading, .error],
                @ViewBuilder content: @escaping (Value) -> Content,
                @ViewBuilder error: @escaping (Error) -> ErrorView) where LoadingView == ResourceLoadingView {
        self.init(
            resource,
            stateOrder: stateOrder,
            loading: { ResourceLoadingView() },
            content: content,
            error: error
        )
    }

    public var body: some View {
        ZStack {
            switch resource.state(order: stateOrder) {
            case .loaded(let value):
                content(value)
            case .error(let error):
                self.error(error)
            case .loading:
                loading()
            case .unloaded:
                Spacer()
            }
        }
    }
}

public struct ResourceLoadingView: View {
    
    public var body: some View {
        Spacer()
        ProgressView()
        Spacer()
    }
}
