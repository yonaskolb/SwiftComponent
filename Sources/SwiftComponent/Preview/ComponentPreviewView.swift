//
//  SwiftUIView.swift
//  
//
//  Created by Yonas Kolb on 22/10/2022.
//

import SwiftUI
import SwiftPreview
import SwiftGUI

struct ComponentPreviewView<Preview: ComponentPreview>: View {

    @StateObject var viewModel = ViewModel<Preview.ComponentType>.init(state: Preview.states[0].state)

    var body: some View {
        HStack(spacing: 0) {
            Preview.ComponentViewType(model: viewModel)
                .preview()
                .padding()
            Divider()
            ComponentPreviewMenuView<Preview>(viewModel: viewModel)
        }
        .previewDevice(.largestDevice)
        .edgesIgnoringSafeArea(.all)
    }
}

struct ComponentPreviewMenuView<Preview: ComponentPreview>: View {

    @ObservedObject var viewModel: ViewModel<Preview.ComponentType>
    @State var testState: [String: TestState] = [:]
    @State var runningTests = false
    @State var render = UUID()
    @AppStorage("autoRunTests") var autoRunTests = false
    @AppStorage("previewTests") var previewTests = true
    @AppStorage("showTestEvents") var showTestEvents = false

    var events: [AnyEvent] {
        componentEvents(for: viewModel.path, includeChildren: true)
    }

    func getTestState(_ test: Test<Preview.ComponentType>) -> TestState {
        testState[test.name] ?? .notRun
    }

    enum TestState: Equatable {
        case notRun
        case running
        case failed([TestError])
        case success
        case pending

        var errors: [TestError]? {
            switch self {
                case .failed(let errors):
                    if !errors.isEmpty { return errors}
                default: break
            }
            return nil
        }

        var color: Color {
            switch self {
                case .notRun: return .accentColor
                case .running: return .gray
                case .failed: return .red
                case .success: return .green
                case .pending: return .gray
            }
        }
    }

    func clearEvents() {
        viewModelEvents = []
        render = UUID()
    }

    func runAllTests() {
        Task { @MainActor in
            await runAllTestsOnMain()
        }
    }

    @MainActor
    func runAllTestsOnMain() async {
        Preview.tests.forEach { testState[$0.name] = .pending }
        for test in Preview.tests {
            await runTest(test)
        }
    }

    @MainActor
    func runTest(_ test: Test<Preview.ComponentType>) async {
        runningTests = true
        testState[test.name] = .running

        let viewModel: ViewModel<Preview.ComponentType>
        let delay: TimeInterval = previewTests ? 0.2 : 0
        if delay > 0 {
            viewModel = self.viewModel
        } else {
            viewModel = ViewModel(state: test.initialState)
        }
        viewModel.path.suffix = " Test: \(test.name)"
        let errors = await viewModel.runTest(test, delay: delay, sendEvents: showTestEvents)
        viewModel.path.suffix = nil
        if errors.isEmpty {
            testState[test.name] = .success
        } else {
            testState[test.name] = .failed(errors)
        }
        runningTests = false
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationView {
                form
                    .navigationTitle(Text("\(Preview.ComponentType.name) Component"))
                    .navigationBarTitleDisplayMode(.inline)
                    .frame(minHeight: 0)
            }
//            Divider()
//            NavigationView {
//                SwiftView(value: viewModel.binding(\.self), config: Config(editing: true))
//            }
            .navigationViewStyle(.stack)
        }
        .task {
            if autoRunTests {
                runAllTests()
            }
        }
        .navigationViewStyle(.stack)
    }

    var form: some View {
        Form {
            if !Preview.states.isEmpty {
                statesSection
            }
            stateSection
            if !Preview.tests.isEmpty {
                testSettingsSection
                testSection
            }
            eventsSection
        }
        .animation(.default, value: events.count)
        .animation(.default, value: testState)
    }

    var testSettingsSection: some View {
        Section(header: Text("Test Settings")) {
            Toggle("Auto Run Tests", isOn: $autoRunTests)
            Toggle("Preview Tests", isOn: $previewTests)
            Toggle("Show Test Events", isOn: $showTestEvents)
        }
    }

    var statesSection: some View {
        Section(header: Text("States")) {
            ForEach(Preview.states, id: \.name) { state in
                Button {
                    withAnimation {
                        viewModel.state = state.state
                    }
                } label: {
                    Text(state.name)
                }
            }
        }
    }

    var stateSection: some View {
        Section(header: Text("State")) {
            SwiftView(value: viewModel.binding(\.self), config: Config(editing: true))
                .showRootNavTitle(false)
        }
    }

    var testSection: some View {
        Section(header: testHeader) {
            ForEach(Preview.tests, id: \.name) { test in
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        Task { @MainActor in
                            await runTest(test)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            ZStack {
                                ProgressView().hidden()
                                switch getTestState(test) {
                                    case .running:
                                        ProgressView().progressViewStyle(CircularProgressViewStyle())
                                    case .failed:
                                        Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                                    case .success:
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                    case .notRun:
                                        Image(systemName: "circle")
                                    case .pending:
                                        Image(systemName: "play.circle").foregroundColor(.gray)
                                }
                            }
                            .foregroundColor(getTestState(test).color)
                            Text(test.name)
                            Spacer()
                            if !runningTests {
                                Image(systemName: "play.circle")
                                    .font(.title3)
                            }
                        }
                        .animation(nil)
                    }
                    if let errors = getTestState(test).errors {
                        Divider()
                            .padding(.horizontal, 20)
                        ForEach(Array(errors.enumerated()), id: \.1) { (index, error) in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(index + 1). \(error.error)")
                                    .foregroundColor(.red)
                                if let detail = error.errorDetail {
                                    Text(detail)
                                    //                                                .font(.footnote)
                                }
                            }
                        }
                    }
                }

            }
        }
        .disabled(runningTests)
    }

    var testHeader: some View {
        HStack {
            Text("Tests")
            Spacer()
            Button(action: runAllTests) {
                Text("Run all")
            }
            .buttonStyle(.plain)
        }
    }

    var eventsSection: some View {
        Section(header: eventsHeader) {
            ComponentEventList(viewModel: viewModel, events: events.reversed(), showMutations: false)
            .id(render)
        }
    }

    var eventsHeader: some View {
        HStack {
            Text("Events")
            Spacer()
            Button(action: clearEvents) {
                Text("Clear")
            }
            .buttonStyle(.plain)
        }
    }
}

struct ComponentPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        ComponentPreviewView<ExamplePreview>()
    }
}
