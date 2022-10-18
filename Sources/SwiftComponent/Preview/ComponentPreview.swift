//
//  File.swift
//  
//
//  Created by Yonas Kolb on 18/10/2022.
//

import Foundation
import SwiftUI

public protocol ComponentPreview: PreviewProvider {
    associatedtype ComponentType: Component
    associatedtype ComponentViewType: ComponentView where ComponentType == ComponentViewType.C
    typealias ComponentState = StateInfo<ComponentType.State>

    @StateBuilder static var states: [ComponentState] { get }
    static var embedInNav: Bool { get }
}

extension ComponentPreview {

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
            #if DEBUG
            componentPreview()
            #endif
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
        return ComponentInfo(component: ComponentType.self, view: view, viewModel: viewModel, states: states) { state in
            createView(createComponentView(state: state))
        }
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
    public static func buildBlock<State>() -> [StateInfo<State>] { [] }
    public static func buildBlock<State>(_ states: StateInfo<State>...) -> [StateInfo<State>] { states }
    public static func buildBlock<State>(_ states: [StateInfo<State>]) -> [StateInfo<State>] { states }
}

public struct StateInfo<State> {
    public let name: String
    public let state: State
    public let size: CGSize?

    public init(_ name: String? = nil, size: CGSize? = nil, _ state: () -> State) {
        self.name = name ?? "Default"
        self.size = size
        self.state = state()
    }
}

public struct ComponentInfo: Identifiable {

    public var id: String { name }
    public var name: String
    public var states: [String]
    public var view: AnyView
    private let createView: (Any) -> AnyView
    private var statesByName: [String: StateInfo<Any>]
    private var applyState: (Any) -> Void

    init<ComponentType: Component>(
        component: ComponentType.Type,
        view: AnyView,
        viewModel: ViewModel<ComponentType>,
        states: [StateInfo<ComponentType.State>],
        createView: @escaping (ComponentType.State) -> AnyView
    ) {
        self.name = String(describing: ComponentType.self)
        self.view = view
        var stateDictionary: [String: StateInfo<Any>] = [:]
        for state in states {
            stateDictionary[state.name] = StateInfo(state.name) { state.state }
        }
        self.statesByName = stateDictionary
        self.states = states.map { $0.name }
        self.applyState = { state in
            let state = state as! ComponentType.State
            viewModel.state = state
        }
        self.createView = { state in
            let state = state as! ComponentType.State
            return createView(state)
        }
    }

    public func state(name: String) -> StateInfo<Any> {
        statesByName[name]!
    }

    public func applyState(name: String) {
        let state = statesByName[name]!.state
        self.applyState(state)
    }

    public func applyState(_ state: Any) {
        self.applyState(state)
    }

    public func view(with state: String) -> AnyView {
        let state = statesByName[state]!.state
        return createView(state)
    }
}
