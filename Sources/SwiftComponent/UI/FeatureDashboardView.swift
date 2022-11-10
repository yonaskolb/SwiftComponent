import Foundation
import SwiftUI
import SwiftPreview
import SwiftGUI

struct FeatureDashboardView<Feature: ComponentFeature>: View {

    @StateObject var viewModel = ViewModel<Feature.Model>.init(state: Feature.states[0].state)

    @AppStorage("componentPreview.showView") var showView = true
    @AppStorage("componentPreview.showComponent") var showComponent = true
    @AppStorage("autoRunTests") var autoRunTests = false
    @AppStorage("previewTests") var previewTests = true
    @AppStorage("showTestEvents") var showTestEvents = false
    @State var testState: [String: TestState<Feature.Model>] = [:]
    @State var runningTests = false
    @State var render = UUID()
    @State var previewTestDelay = 0.5

    var events: [ComponentEvent] {
        viewModelEvents
    }

    func getTestState(_ test: Test<Feature.Model>) -> TestState<Feature.Model> {
        testState[test.name] ?? .notRun
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
        Feature.tests.forEach { testState[$0.name] = .pending }
        for test in Feature.tests {
            await runTest(test)
        }
    }

    @MainActor
    func runTest(_ test: Test<Feature.Model>) async {
        runningTests = true
        testState[test.name] = .running

        guard let state = Feature.state(for: test) else {
            testState[test.name] = .failedToRun(TestError(error: "Could not find state", source: test.source))
            return
        }
        let delay: TimeInterval = previewTests ? previewTestDelay : 0

        let viewModel: ViewModel<Feature.Model>
        if delay > 0 {
            viewModel = self.viewModel
        } else {
            viewModel = ViewModel(state: state)
        }
        viewModel.path.suffix = " Test: \(test.name)"
        let result = await viewModel.runTest(test, initialState: state, delay: delay, sendEvents: showTestEvents)
        viewModel.path.suffix = nil
        testState[test.name] = .complete(result)
        runningTests = false
    }

    var body: some View {
        HStack(spacing: 0) {
            if showView {
                ViewPreviewer(content: Feature.createView(model: viewModel), showEnvironmentPickers: false)
                    .padding()
            }
            if showComponent {
                NavigationView {
                    form
                        .task {
                            if autoRunTests {
                                runAllTests()
                            }
                        }
                }
                .navigationViewStyle(.stack)
            }
        }
    }

    var form: some View {
        Form {
            if !Feature.states.isEmpty {
                statesSection
            }
            stateSection
            if !Feature.tests.isEmpty {
                testSettingsSection
                testSection
            }
            eventsSection
        }
        .animation(.default, value: events.count)
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
            ForEach(Feature.states, id: \.name) { state in
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
            ForEach(Feature.tests, id: \.name) { test in
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        Task { @MainActor in
                            await runTest(test)
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            HStack(spacing: 8) {
                                ZStack {
                                    ProgressView().hidden()
                                    switch getTestState(test) {
                                        case .running:
                                            ProgressView().progressViewStyle(CircularProgressViewStyle())
                                        case .failedToRun:
                                            Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                                        case .complete(let result):
                                            if result.success {
                                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                            } else {
                                                Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                                            }
                                        case .notRun:
                                            Image(systemName: "circle")
                                        case .pending:
                                            Image(systemName: "play.circle").foregroundColor(.gray)
                                    }
                                }
                                .foregroundColor(getTestState(test).color)
                                Text(test.name)
                                    .foregroundColor(getTestState(test).color)
                                Spacer()
                                if let error = getTestState(test).errors?.first {
                                    Text(error.error).foregroundColor(.red)
                                        .lineLimit(1)
                                }
                                if !runningTests {
                                    Image(systemName: "play.circle")
                                        .font(.title3)
                                }
                            }
                            .animation(nil)
                            if let error = getTestState(test).errors?.first {
                                VStack(alignment: .leading) {
                                    //                                    Text(error.error)
                                    //                                        .foregroundColor(.red)
                                    //                                        .lineLimit(1)
                                    //                                        .padding(.leading, 20)
                                    if let diff = error.diff {
                                        VStack(alignment: .leading) {
                                            diff
                                                .diffText()
                                        }
                                        .padding(4)
                                    }
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
            ComponentEventList(events: events.sorted { $0.start < $1.start }, allEvents: events.sorted { $0.start < $1.start })
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

struct ComponentFeatureDashboard_Previews: PreviewProvider {
    static var previews: some View {
        FeatureDashboardView<ExamplePreview>()
    }
}
