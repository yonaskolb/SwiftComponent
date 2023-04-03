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
                view(model: ViewModel(state: state.state))
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
        if let testState = test.state {
            return testState
        } else if let stateName = test.stateName, let namedState = Self.state(name: stateName) {
            return namedState
        }
        return nil
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

    public init(_ name: String? = nil, size: CGSize? = nil, route: Model.Route? = nil, _ state: () -> Model.State) {
        self.init(name, size: size, route: route, state: state())
    }

    public init(_ name: String? = nil, size: CGSize? = nil, route: Model.Route? = nil, state: Model.State) {
        self.name = name ?? "Default"
        self.size = size
        self.route = route
        self.state = state
    }
}

extension ComponentState {
    public func viewModel() -> ViewModel<Model> {
        ViewModel(state: state, route: route)
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
