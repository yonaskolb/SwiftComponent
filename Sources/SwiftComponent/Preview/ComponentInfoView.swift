//
//  File.swift
//  
//
//  Created by Yonas Kolb on 18/10/2022.
//

import Foundation
import SwiftUI
import SwiftGUI

#if DEBUG

public struct ComponentInfo: Identifiable {

    public var id: String { componentName + viewName }
    var componentName: String
    var viewName: String
    var states: [String]
    var view: AnyView
    private let createView: (Any) -> AnyView
    private var statesByName: [String: ComponentPreviewState<Any>]
    var applyState: (Any) -> Void
    var applyAction: (Any) -> Void
    var runTest: @MainActor (TestInfo, TimeInterval) async -> Void
    var tests: [TestInfo]

    init<ComponentType: Component, ComponentViewType: ComponentView>(
        component: ComponentType.Type,
        componentView: ComponentViewType.Type,
        view: AnyView,
        viewModel: ViewModel<ComponentType>,
        states: [ComponentPreviewState<ComponentType.State>],
        tests: [Test<ComponentType>],
        createView: @escaping (ComponentType.State) -> AnyView
    ) {
        self.componentName = String(describing: ComponentType.self)
        self.viewName = String(describing: ComponentViewType.self)
        self.view = view
        var stateDictionary: [String: ComponentPreviewState<Any>] = [:]
        for state in states {
            stateDictionary[state.name] = ComponentPreviewState(state.name) { state.state }
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

    public func state(name: String) -> ComponentPreviewState<Any> {
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

public struct TestInfo {
    let name: String
    let stepCount: Int
}

public struct ComponentInfoView: View {

    let component: ComponentInfo
    @Binding var state: String?
    @State var render = UUID()

    var stateBinding: Binding<Any> {
        Binding<Any>(
            get: { component.state(name: state!).state },
            set: { component.applyState($0) }
        )
    }

    func playTest(_ test: TestInfo) {
        Task { @MainActor in
            await component.runTest(test, 0.2)
        }
    }

    public var body: some View {
        VStack(alignment: .leading) {
            section("States")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(component.states, id: \.self) { state in
                    Button(action: {
                        self.state = state
                        self.render = UUID()
                        withAnimation {
                            component.applyState(name: state)
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 0) {
                            Divider()
                            HStack {
                                Text(state)
                                //                                    .color(self.state == state ? .white : .gray)
                                //                                    .midnight()
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            Divider()
                        }

                        //                        .background(self.state == state ? Color.background : Color.systemBackground)
                    }
                }
            }
            if !component.tests.isEmpty {
                section("Tests")
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(component.tests, id: \.name) { test in
                        Button(action: { playTest(test) }) {
                            VStack(alignment: .leading, spacing: 0) {
                                Divider()
                                HStack {
                                    Text(test.name)
                                    Spacer()
                                    Text(test.stepCount.description)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                Divider()
                            }
                        }
                    }
                }
            }
            if state != nil {
                VStack(alignment: .leading, spacing: 0) {
                    section("State Editor")
                    Divider()
                    NavigationView {
                        SwiftView(value: stateBinding, config: Config(editing: true))
                    }
                    .animation(nil)
                    .id(state!)
                    .navigationViewStyle(StackNavigationViewStyle())
                }
                .padding(.top, 40)
            }
        }
        .padding(.top)
    }

    func section(_ title: String) -> some View {
        Text(title.uppercased())
            .foregroundColor(.gray)
            .font(.footnote)
            .padding(.horizontal)
            .padding(.bottom)
    }
}

struct ComponentInfoView_Previews: PreviewProvider {

    static var previews: some View {
        ComponentInfoView(component: ExamplePreview.componentInfo, state: .constant(nil))
    }
}
#endif
