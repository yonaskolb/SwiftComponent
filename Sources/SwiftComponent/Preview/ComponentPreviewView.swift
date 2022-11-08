//
//  SwiftUIView.swift
//  
//
//  Created by Yonas Kolb on 22/10/2022.
//

import SwiftUI
import SwiftPreview
import SwiftGUI

struct ComponentPreviewView<Preview: ComponentFeature>: View {

    @StateObject var viewModel = ViewModel<Preview.ModelType>.init(state: Preview.states[0].state)
    @AppStorage("componentPreview.showView") var showView = true
    @AppStorage("componentPreview.showComponent") var showComponent = true
    @AppStorage("componentPreview.viewState") var viewState: ViewState = .dashboard

    enum ViewState: String, CaseIterable {
        case dashboard = "Dashboard"
        case view = "View"
        case model = "Model"
        case code = "Code"
        case tests = "Tests"
    }

    var body: some View {
        NavigationView {
            Group {
                switch viewState {
                    case .dashboard:
                        component
                    case .view:
                        Preview.createView(model: viewModel)
                            .preview()
                            .padding()
                    case .tests:
                        tests
//                        NavigationView {
//                            ComponentPreviewMenuView<Preview>(viewModel: viewModel)
//                                .navigationTitle(Text(String(describing: Preview.ComponentType.self)))
//                                .navigationBarTitleDisplayMode(.inline)
//                        }
//                        .navigationViewStyle(.stack)
                    case .code:
                        ComponentEditorView<Preview>()
                    case .model:
                        VStack {
                            Text(Preview.ModelType.baseName).bold()
                        }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker(selection: $viewState) {
                        ForEach(ViewState.allCases, id: \.rawValue) { viewState in
                            Text(viewState.rawValue).tag(viewState)
                        }
                    } label: {
                        Text("Mode")
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }
        }
        .navigationViewStyle(.stack)
        .previewDevice(.largestDevice)
        .edgesIgnoringSafeArea(.all)
    }

    var component: some View {
        HStack(spacing: 0) {
            if showView {
                //NavigationView {
                Preview.createView(model: viewModel)
                    .preview()
                    .padding()
                    .navigationTitle(Text(String(describing: Preview.ViewType.self)))
                    .navigationBarTitleDisplayMode(.inline)
//                    .toolbar {
//                        ToolbarItem(placement: .navigationBarTrailing) {
//                            Button(action: { withAnimation { showComponent = !showComponent }}) {
//                                Image(systemName: showComponent ? "rectangle.trailinghalf.inset.filled.arrow.trailing" : "rectangle.trailinghalf.filled")
//                            }
//                        }
//                    }
//                //}
//                    .transition(.move(edge: .leading))
//                    .animation(.default, value: showView)
            }
            //            Divider()
            if showComponent {
                NavigationView {
                    menuView
                        .navigationTitle(Text(String(describing: Preview.ModelType.self)))
                        .navigationBarTitleDisplayMode(.inline)
//                        .toolbar {
//                            ToolbarItem(placement: .navigationBarLeading) {
//                                Button(action: { withAnimation { showView = !showView }}) {
//                                    Image(systemName: showView ? "rectangle.leadinghalf.inset.filled.arrow.leading" : "rectangle.leadinghalf.filled")
//                                }
//                            }
//                        }
                }
                .navigationViewStyle(.stack)
//                .transition(.move(edge: .leading))
//                .animation(.default, value: showComponent)
            }
        }
    }

    var menuView: some View {
        form
            .task {
                if autoRunTests {
                    runAllTests()
                }
            }
    }

    var tests: some View {
        ScrollView {
            LazyVStack(spacing: 30) {
                ForEach(Preview.tests, id: \.name) { test in
                    testRow(test)
                    Divider()
                }
            }
//            .animation(.default)
            .padding(.horizontal, 20)
        }
        .task {
            runAllTests()
        }
    }

    func testRow(_ test: Test<Preview.ModelType>) -> some View {
        VStack(alignment: .leading) {
            testHeader(test)
                .padding(.bottom, 8)
            if let steps = testResults[test.name] {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(steps, id: \.self) { step in
                        if let stepResult = testStepResults[step] {
                            stepResultRow(stepResult)
                        }
                    }
                }
                .padding(.leading, 30)
            }
        }
    }

    func stepResultRow(_ stepResult: TestStepResult<Preview.ModelType>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                if stepResult.success {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                } else {
                    Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                }
                HStack(spacing: 0) {
                    Text(stepResult.step.title)
                        .bold()
                    if let details = stepResult.step.details {
                        Text(": \(details)")
                            .lineLimit(1)
                    }
                }
                .foregroundColor(stepResult.success ? .green : .red)
            }
            if !stepResult.events.isEmpty {
                VStack(alignment: .leading, spacing:8) {
                    ForEach(stepResult.events.sorted { $0.start < $1.start }) { event in
                        HStack {
//                            Text(event.type.emoji)
                            Text("Event: ") +
                            Text(event.type.title).bold() +
                            Text(" " + event.type.details)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 28)
                .padding(.top, 8)
            }
            if !stepResult.errors.isEmpty {
                ForEach(stepResult.errors, id: \.id) { error in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error.error)
                            .foregroundColor(.red)
                        if let diff = error.diff {
                            VStack(alignment: .leading, spacing: 4) {
                                diff.diffText()
//                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(16)
                            .background {
                                RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1))
                            }
                            .background {
                                RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2))
                            }
                        }
                    }
                }
                .padding(.leading, 30)
            }
        }
    }

    func testHeader(_ test: Test<Preview.ModelType>) -> some View {
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
                    .bold()
                    .foregroundColor(getTestState(test).color)
                Spacer()
//                if !runningTests {
//                    Image(systemName: "play.circle")
//                        .font(.title3)
//                }
            }
            .animation(nil)
            .font(.title3)
        }
        .buttonStyle(.plain)
    }


    @State var testState: [String: TestState] = [:]
    @State var testResults: [String: [TestStep<Preview.ModelType>.ID]] = [:]
    @State var testStepResults: [TestStep<Preview.ModelType>.ID: TestStepResult<Preview.ModelType>] = [:]
    @State var runningTests = false
    @State var render = UUID()
    @AppStorage("autoRunTests") var autoRunTests = false
    @AppStorage("previewTests") var previewTests = true
    @AppStorage("showTestEvents") var showTestEvents = false

    var events: [ComponentEvent] {
        viewModelEvents
    }

    func getTestState(_ test: Test<Preview.ModelType>) -> TestState {
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
    func runTest(_ test: Test<Preview.ModelType>) async {
        runningTests = true
        testState[test.name] = .running

        let viewModel: ViewModel<Preview.ModelType>
        let state: Preview.ModelType.State
        if let testState = test.state {
            state = testState
        } else if let stateName = test.stateName {
            if let namedState = Preview.state(name: stateName) {
                state = namedState
            } else {
                testState[test.name] = .failed([TestError(error: "Could not find state \"\(stateName)\"", source: test.source)])
                return
            }
        } else {
            testState[test.name] = .failed([TestError(error: "Could not find state", source: test.source)])
            return
        }

        let delay: TimeInterval = previewTests ? 0.3 : 0

        if delay > 0 {
            viewModel = self.viewModel
        } else {
            viewModel = ViewModel(state: state)
        }
        viewModel.path.suffix = " Test: \(test.name)"
        testResults[test.name] = []
        let result = await viewModel.runTest(test, initialState: state, delay: delay, sendEvents: showTestEvents) { result in
            Task { @MainActor in
                testResults[test.name, default: []].append(result.id)
                testStepResults[result.id] = result
            }
        }
        viewModel.path.suffix = nil
        if result.success {
            testState[test.name] = .success
        } else {
            testState[test.name] = .failed(result.errors)
        }
        runningTests = false
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
            ComponentEventList(events: events.sorted { $0.start > $1.start }, allEvents: events.sorted { $0.start > $1.start })
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

extension String {

    private func getLine(_ line: String) -> Text {
        var line = String(line)
        var color = Color.secondary
        var change: Bool = false
        if line.hasPrefix("+") {
            line = " " + String(line.dropFirst(1))
            color = .green
            change = true
        } else if line.hasPrefix("-") {
            line = " " + String(line.dropFirst(1))
            color = .red
            change = true
        }
        var text = Text(line)
            .foregroundColor(color)
        if change {
           // text = text.bold()
        }
        return text
    }

    func diffText() -> some View {
        ForEach(Array(self.components(separatedBy: "\n").enumerated()), id: \.0) { _, line in
            getLine(line)
        }
    }
}

struct ComponentPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        ComponentPreviewView<ExamplePreview>()
    }
}
