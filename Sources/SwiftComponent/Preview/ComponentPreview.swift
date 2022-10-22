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
    typealias ComponentTest = Test<ComponentType>

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
        return ComponentInfo(
            component: ComponentType.self,
            componentView: ComponentViewType.self,
            view: view,
            viewModel: viewModel,
            states: states, tests: tests) { state in
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

@resultBuilder
public struct TestBuilder {
    public static func buildBlock<ComponentType: Component>() -> [Test<ComponentType>] { [] }
    public static func buildBlock<ComponentType: Component>(_ tests: Test<ComponentType>...) -> [Test<ComponentType>] { tests }
    public static func buildBlock<ComponentType: Component>(_ tests: [Test<ComponentType>]) -> [Test<ComponentType>] { tests }
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

public struct TestInfo {
    let name: String
    let stepCount: Int
}

public struct ComponentInfo: Identifiable {

    public var id: String { componentName + viewName }
    var componentName: String
    var viewName: String
    var states: [String]
    var view: AnyView
    private let createView: (Any) -> AnyView
    private var statesByName: [String: StateInfo<Any>]
    var applyState: (Any) -> Void
    var applyAction: (Any) -> Void
    var runTest: @MainActor (TestInfo, TimeInterval) async -> Void
    var tests: [TestInfo]

    init<ComponentType: Component, ComponentViewType: ComponentView>(
        component: ComponentType.Type,
        componentView: ComponentViewType.Type,
        view: AnyView,
        viewModel: ViewModel<ComponentType>,
        states: [StateInfo<ComponentType.State>],
        tests: [Test<ComponentType>],
        createView: @escaping (ComponentType.State) -> AnyView
    ) {
        self.componentName = String(describing: ComponentType.self)
        self.viewName = String(describing: ComponentViewType.self)
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
        self.applyAction = { action in
            let action = action as! ComponentType.Action
            viewModel.handleAction(action, sourceLocation: .capture(file: #file, fileID: #fileID, line: #line))
        }
        self.createView = { state in
            let state = state as! ComponentType.State
            return createView(state)
        }

        var testByName: [String: (TimeInterval) async -> Void] = [:]
        for test in tests {
            testByName[test.name] = { delay in
                await viewModel.runTest(test, delay: delay)
            }
        }

        self.tests = tests.map { test in
            TestInfo(name: test.name, stepCount: test.steps.count)
        }

        runTest = { testInfo, delay in
            let runner = testByName[testInfo.name]!
            await runner(delay)
        }
    }

    public func state(name: String) -> StateInfo<Any> {
        statesByName[name]!
    }

    public func applyState(name: String) {
        let state = statesByName[name]!.state
        self.applyState(state)
    }

    public func view(with state: String) -> AnyView {
        let state = statesByName[state]!.state
        return createView(state)
    }
}
