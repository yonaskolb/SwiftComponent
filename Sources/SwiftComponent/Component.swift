import Foundation
import SwiftUI

public protocol Component: PreviewProvider {
    associatedtype Model: ComponentModel
    associatedtype ViewType: View

    typealias States = [ComponentState<Model.State>]
    typealias State = ComponentState<Model.State>

    typealias Tests = [Test<Model>]
    typealias Step = TestStep<Model>

    typealias Route = ComponentModelRoute<Model.Route>
    typealias Routes = [Route]

    @StateBuilder static var states: States { get }
    @TestBuilder static var tests: Tests { get }
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
                .previewDisplayName(Model.baseName + " Component")
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
    public static func buildBlock<State>() -> [ComponentState<State>] { [] }
    public static func buildBlock<State>(_ states: ComponentState<State>...) -> [ComponentState<State>] { states }
    public static func buildBlock<State>(_ states: [ComponentState<State>]) -> [ComponentState<State>] { states }
}

public struct ComponentState<State> {
    public let name: String
    public let state: State
    public let size: CGSize?

    public init(_ name: String? = nil, size: CGSize? = nil, _ state: () -> State) {
        self.init(name, size: size, state())
    }

    public init(_ name: String? = nil, size: CGSize? = nil, _ state: State) {
        self.name = name ?? "Default"
        self.size = size
        self.state = state
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
