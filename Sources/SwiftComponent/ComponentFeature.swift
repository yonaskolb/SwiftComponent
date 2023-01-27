import Foundation
import SwiftUI

public protocol ComponentFeature: PreviewProvider {
    associatedtype Model: ComponentModel
    associatedtype ViewType: View
    typealias ComponentState = ComponentPreviewState<Model.State>
    typealias ComponentTest = Test<Model>
    typealias ComponentRoute = ComponentFeatureRoute<Model.Route>
    typealias Step = TestStep<Model>
    typealias State = Model.State

    @StateBuilder static var states: [ComponentState] { get }
    @TestBuilder static var tests: [ComponentTest] { get }
    @RouteBuilder static var routes: [ComponentRoute] { get }
    static func createView(model: ViewModel<Model>) -> ViewType
    static var embedInNav: Bool { get }
}
    
extension ComponentFeature where ViewType: ComponentView, ViewType.Model == Model {

    public static func createView(model: ViewModel<Model>) -> ViewType {
        ViewType(model: model)
    }
    static var testAssertions: Set<TestAssertion> { get }
}

extension ComponentFeature {

    public static var routes: [ComponentRoute] { [] }
    public static var testAssertions: Set<TestAssertion> { .normal }
}

extension ComponentFeature {

    public static var tests: [Test<Model>] { [] }

    static func embedView(state: Model.State) -> AnyView {
        let viewModel = ViewModel<Model>(state: state)
        let view = createView(model: viewModel)
        if config.embedInNav {
            return NavigationView { view }.eraseToAnyView()
        } else {
            return view.eraseToAnyView()
        }
    }

    static var config: PreviewConfig { PreviewConfig(embedInNav: embedInNav) }
    public static var embedInNav: Bool { false }
    public static var previews: some View {
        Group {
            componentPreview
                .previewDisplayName(Model.baseName + " Component")
            ForEach(states, id: \.name) { state in
                embedView(state: state.state)
                    .previewDisplayName("State: \(state.name)")
                    .previewReference()
                    .previewLayout(state.size.flatMap { PreviewLayout.fixed(width: $0.width, height: $0.height) } ?? PreviewLayout.device)
            }
        }
    }

    public static var componentPreview: some View {
        NavigationView {
            FeaturePreviewView<Self>()
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

public struct PreviewConfig {

    public init(embedInNav: Bool) {
        self.embedInNav = embedInNav
    }

    var embedInNav: Bool
}

@resultBuilder
public struct StateBuilder {
    public static func buildBlock<State>() -> [ComponentPreviewState<State>] { [] }
    public static func buildBlock<State>(_ states: ComponentPreviewState<State>...) -> [ComponentPreviewState<State>] { states }
    public static func buildBlock<State>(_ states: [ComponentPreviewState<State>]) -> [ComponentPreviewState<State>] { states }
}

public struct ComponentPreviewState<State> {
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
    public static func buildBlock<Route>() -> [ComponentFeatureRoute<Route>] { [] }
    public static func buildBlock<Route>(_ routes: ComponentFeatureRoute<Route>...) -> [ComponentFeatureRoute<Route>] { routes }
    public static func buildBlock<Route>(_ routes: [ComponentFeatureRoute<Route>]) -> [ComponentFeatureRoute<Route>] { routes }
}

public struct ComponentFeatureRoute<Route> {
    public let name: String
    public let route: Route
    public init(_ name: String, _ route: Route) {
        self.name = name
        self.route = route
    }
}
