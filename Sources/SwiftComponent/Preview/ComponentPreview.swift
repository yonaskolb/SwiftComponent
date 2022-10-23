//
//  File.swift
//  
//
//  Created by Yonas Kolb on 18/10/2022.
//

import Foundation
import SwiftUI

#if DEBUG
public protocol ComponentPreview<ComponentType, ComponentViewType>: PreviewProvider {
    associatedtype ComponentType: Component
    associatedtype ComponentViewType: ComponentView where ComponentType == ComponentViewType.C
    typealias ComponentState = ComponentPreviewState<ComponentType.State>
    typealias ComponentTest = Test<ComponentType>
    typealias Step = ComponentTest.Step
    typealias State = ComponentType.State

    @StateBuilder static var states: [ComponentState] { get }
    @TestBuilder static var tests: [ComponentTest] { get }
    static var embedInNav: Bool { get }
}

extension ComponentPreview {

    public static var tests: [ComponentTest] { [] }
    static func createComponentView(state: ComponentType.State) -> ComponentViewType {
        ComponentViewType(model: ViewModel<ComponentType>(state: state))
    }

    static func createView(_ componentView: ComponentViewType) -> AnyView {
        var view: AnyView
        if config.embedInNav {
            view = NavigationView { componentView }.eraseToAnyView()
        } else {
            view = componentView.eraseToAnyView()
        }
        return view
    }

    static var config: PreviewConfig { PreviewConfig(embedInNav: embedInNav) }
    public static var embedInNav: Bool { false }
    public static var previews: some View {
        Group {
            componentPreview
            ForEach(states, id: \.name) { state in
                createView(createComponentView(state: state.state))
                    .previewDisplayName("\(String(describing: ComponentViewType.self).replacingOccurrences(of: "View", with: "")) \(state.name)" )
                    .previewLayout(state.size.flatMap { PreviewLayout.fixed(width: $0.width, height: $0.height) } ?? PreviewLayout.device)
            }
        }
    }

    public static var componentInfo: ComponentInfo {
        let state = states.first!.state
        let component = createComponentView(state: state)
        let viewModel = component.model
        let view = createView(component)
        return ComponentInfo(
            component: ComponentType.self,
            componentView: ComponentViewType.self,
            view: view,
            viewModel: viewModel,
            states: states, tests: tests) { state in
            createView(createComponentView(state: state))
        }
    }

    public static var componentPreview: some View {
        ComponentPreviewView<Self>()
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
        self.name = name ?? "Default"
        self.size = size
        self.state = state()
    }
}

#endif
