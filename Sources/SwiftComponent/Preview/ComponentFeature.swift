//
//  File.swift
//  
//
//  Created by Yonas Kolb on 18/10/2022.
//

import Foundation
import SwiftUI

#if DEBUG
public protocol ComponentFeature: PreviewProvider {
    associatedtype ModelType: ComponentModel
    associatedtype ViewType: View
    typealias ComponentState = ComponentPreviewState<ModelType.State>
    typealias ComponentTest = Test<ModelType>
    typealias Step = TestStep<ModelType>
    typealias State = ModelType.State

    @StateBuilder static var states: [ComponentState] { get }
    @TestBuilder static var tests: [ComponentTest] { get }
    static func createView(model: ViewModel<ModelType>) -> ViewType
    static var embedInNav: Bool { get }
}
    
extension ComponentFeature where ViewType: ComponentView, ViewType.Model == ModelType {

    public static func createView(model: ViewModel<ModelType>) -> ViewType {
        ViewType(model: model)
    }
}

extension ComponentFeature {

    public static var tests: [Test<ModelType>] { [] }

    static func embedView(state: ModelType.State) -> AnyView {
        let viewModel = ViewModel<ModelType>(state: state)
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
                .previewDisplayName(ModelType.baseName + " Component")
            ForEach(states, id: \.name) { state in
                embedView(state: state.state)
                    .previewDisplayName("State: \(state.name)")
                    .environment(\.isPreviewReference, true)
                    .previewLayout(state.size.flatMap { PreviewLayout.fixed(width: $0.width, height: $0.height) } ?? PreviewLayout.device)
            }
        }
    }

    public static var componentPreview: some View {
        ComponentPreviewView<Self>()
    }

    public static func state(name: String) -> ModelType.State? {
        states.first { $0.name == name }?.state
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

#endif
