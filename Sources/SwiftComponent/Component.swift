import Foundation
import SwiftUI

public protocol Component: PreviewProvider {
    associatedtype Model: ComponentModel
    associatedtype ViewType: View

    typealias States = [ComponentState<Model>]
    typealias State = ComponentState<Model>

    typealias Tests = [Test<Model>]

    typealias Route = ComponentModelRoute<Model.Route>
    typealias Routes = [Route]

    @StateBuilder static var states: States { get }
    @TestBuilder<Model> static var tests: Tests { get }
    @RouteBuilder static var routes: Routes { get }
    @ViewBuilder static func view(model: ViewModel<Model>) -> ViewType
    static var testAssertions: Set<TestAssertion> { get }
    // provided by tests if they exist
    static var filePath: StaticString { get }
}

extension Component {

    public static var routes: Routes { [] }
    public static var testAssertions: Set<TestAssertion> { .normal }
}

extension Component {

    public static var tests: Tests { [] }

    public static var embedInNav: Bool { false }
    public static var previews: some View {
        Group {
            componentPreview
                .previewDisplayName(Model.baseName)
            ForEach(states, id: \.name) { state in
                view(model: state.viewModel())
                    .previewDisplayName("State: \(state.name)")
                    .previewReference()
                    .previewLayout(state.size.flatMap { PreviewLayout.fixed(width: $0.width, height: $0.height) } ?? PreviewLayout.device)
            }
        }
    }

    public static var componentPreview: some View {
        NavigationView {
            ComponentPreviewView<Self>()
        }
        .navigationViewStyle(.stack)
        .previewDevice(.largestDevice)
    }

    public static func state(name: String) -> Model.State? {
        states.first { $0.name == name }?.state
    }

    public static func state(for test: Test<Model>) -> Model.State? {
        switch test.state {
        case .name(let stateName):
            return Self.state(name: stateName)
        case .state(let state):
            return state
        }
    }

    public static func previewModel() -> ViewModel<Model> {
        states[0].viewModel()
    }
}

extension Component {
    public static var filePath: StaticString { tests.first?.source.file ?? .init() }

    static func readSource() -> String? {
        guard !filePath.description.isEmpty else { return nil }
        guard let data = FileManager.default.contents(atPath: filePath.description) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func writeSource(_ source: String) {
        guard !filePath.description.isEmpty else { return }
        let data = Data(source.utf8)
        FileManager.default.createFile(atPath: filePath.description, contents: data)
    }
}

@resultBuilder
public struct StateBuilder {
    public static func buildBlock<Model: ComponentModel>() -> [ComponentState<Model>] { [] }
    public static func buildBlock<Model: ComponentModel>(_ states: ComponentState<Model>...) -> [ComponentState<Model>] { states }
    public static func buildBlock<Model: ComponentModel>(_ states: [ComponentState<Model>]) -> [ComponentState<Model>] { states }
}

public struct ComponentState<Model: ComponentModel> {
    public let name: String
    public let state: Model.State
    public let route: Model.Route?
    public let size: CGSize?
    public let environment: Model.Environment
    public var dependencies: ComponentDependencies

    public init(_ name: String? = nil, size: CGSize? = nil, route: Model.Route? = nil) where Model.State == Void, Model.Environment: ComponentEnvironment {
        self.init(name, size: size, environment: Model.Environment.preview, route: route, state: ())
    }

    public init(_ name: String? = nil, size: CGSize? = nil, route: Model.Route? = nil) where Model.State == Void, Model.Environment == EmptyEnvironment {
        self.init(name, size: size, environment: EmptyEnvironment(), route: route, state: ())
    }

    public init(_ name: String? = nil, size: CGSize? = nil, environment: Model.Environment, route: Model.Route? = nil) where Model.State == Void {
        self.init(name, size: size, environment: environment, route: route, state: ())
    }

    public init(_ name: String? = nil, size: CGSize? = nil, route: Model.Route? = nil, _ state: () -> Model.State) where Model.Environment: ComponentEnvironment {
        self.init(name, size: size, environment: Model.Environment.preview, route: route, state: state())
    }

    public init(_ name: String? = nil, size: CGSize? = nil, route: Model.Route? = nil, _ state: () -> Model.State) where Model.Environment == EmptyEnvironment {
        self.init(name, size: size, environment: EmptyEnvironment(), route: route, state: state())
    }

    public init(_ name: String? = nil, size: CGSize? = nil, environment: Model.Environment, route: Model.Route? = nil, _ state: () -> Model.State) {
        self.init(name, size: size, environment: environment, route: route, state: state())
    }

    public init(_ name: String? = nil, size: CGSize? = nil, route: Model.Route? = nil, state: Model.State) where Model.Environment: ComponentEnvironment {
        self.init(name, size: size, environment: Model.Environment.preview, route: route, state: state)
    }

    public init(_ name: String? = nil, size: CGSize? = nil, environment: Model.Environment, route: Model.Route? = nil, state: Model.State) {
        self.name = name ?? "Default"
        self.size = size
        self.route = route
        self.state = state
        self.environment = environment
        self.dependencies = .init()
    }

    public func dependency<Value>(_ keyPath: WritableKeyPath<DependencyValues, Value>, _ value: Value) -> Self {
        var state = self
        state.dependencies.setDependency(keyPath, value)
        return state
    }
}

extension ComponentState {
    public func viewModel() -> ViewModel<Model> {
        ViewModel(state: state, environment: environment, route: route).apply(dependencies)
    }
}

@resultBuilder
public struct RouteBuilder {
    public static func buildBlock<Route>() -> [ComponentModelRoute<Route>] { [] }
    public static func buildBlock<Route>(_ routes: ComponentModelRoute<Route>...) -> [ComponentModelRoute<Route>] { routes }
    public static func buildBlock<Route>(_ routes: [ComponentModelRoute<Route>]) -> [ComponentModelRoute<Route>] { routes }
}

public struct ComponentModelRoute<Route> {
    public let name: String
    public let route: Route
    public init(_ name: String, _ route: Route) {
        self.name = name
        self.route = route
    }
}
