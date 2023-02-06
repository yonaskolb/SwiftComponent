import Foundation
import SwiftUI
import SwiftPreview
import SwiftGUI

struct ComponentDashboardView<ComponentType: Component>: View {

    @ObservedObject var model: ViewModel<ComponentType.Model>

    @AppStorage("componentPreview.showView") var showView = true
    @AppStorage("componentPreview.showComponent") var showComponent = true
    @AppStorage("previewTests") var previewTests = true
    @State var showTestEvents = true
    @State var autoRunTests = true
    @State var testState: [String: TestState<ComponentType.Model>] = [:]
    @State var runningTests = false
    @State var render = UUID()
    @State var previewTestDelay = 0.3

    var events: [Event] {
        EventStore.shared.events
    }

    func getTestState(_ test: Test<ComponentType.Model>) -> TestState<ComponentType.Model> {
        testState[test.name] ?? .notRun
    }

    func clearEvents() {
        EventStore.shared.clear()
        render = UUID()
    }

    func runAllTests(delay: TimeInterval) {
        Task { @MainActor in
            await runAllTestsOnMain(delay: delay)
        }
    }

    @MainActor
    func runAllTestsOnMain(delay: TimeInterval) async {
        ComponentType.tests.forEach { testState[$0.name] = .pending }
        for test in ComponentType.tests {
            await runTest(test, delay: delay)
        }
    }

    @MainActor
    func runTest(_ test: Test<ComponentType.Model>, delay: TimeInterval) async {
        runningTests = true
        testState[test.name] = .running

        guard let state = ComponentType.state(for: test) else {
            testState[test.name] = .failedToRun(TestError(error: "Could not find state", source: test.source))
            return
        }

        let model: ViewModel<ComponentType.Model>
        if delay > 0 {
            model = self.model
        } else {
            model = ViewModel(state: state)
        }
        model.store.path.suffix = " Test: \(test.name)"
        let result = await model.runTest(test, initialState: state, assertions: ComponentType.testAssertions, delay: delay, sendEvents: showTestEvents)
        model.store.path.suffix = nil
        testState[test.name] = .complete(result)
        runningTests = false
    }

    var body: some View {
        HStack(spacing: 0) {
            if showView {
                ViewPreviewer(content: ComponentType.view(model: model), showEnvironmentPickers: false)
                    .padding()
                    .frame(maxWidth: .infinity)
//                    .transition(.move(edge: .leading).animation(.default)) // won't animate for some reason
            }
            Divider()
            if showComponent {
                NavigationView {
                    form
                }
                .navigationViewStyle(.stack)
                .frame(maxWidth: .infinity)
//                .transition(.move(edge: .trailing).animation(.default)) // won't animate for some reason
            }
        }
        .task {
            runAllTests(delay: 0)
        }
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button(action: { withAnimation {
//                    showView.toggle()
//                    if !showComponent && !showView {
//                        showComponent = true
//                    }
//
//                }}) {
//                    Image(systemName: "rectangle.leadinghalf.inset.filled")
//                    Text("View")
//                }
//            }
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: { withAnimation {
//                    showComponent.toggle()
//                    if !showComponent && !showView {
//                        showView = true
//                    }
//                }}) {
//                    Text("Model")
//                    Image(systemName: "rectangle.trailinghalf.inset.filled")
//                }
//            }
//        }
    }

    var form: some View {
        Form {
            if !ComponentType.states.isEmpty {
                statesSection
            }
            stateSection
            if !ComponentType.tests.isEmpty {
//                testSettingsSection
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
            ForEach(ComponentType.states, id: \.name) { state in
                Button {
                    withAnimation {
                        model.state = state.state
                    }
                } label: {
                    Text(state.name)
                }
            }
        }
    }

    var stateSection: some View {
        Section(header: Text("State")) {
            SwiftView(value: model.binding(\.self), config: Config(editing: true))
                .showRootNavTitle(false)
        }
    }

    var testSection: some View {
        Section(header: testHeader) {
            ForEach(ComponentType.tests, id: \.name) { test in
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        Task { @MainActor in
                            await runTest(test, delay: previewTestDelay)
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
                                Image(systemName: "play.circle")
                                    .font(.title3)
                                    .disabled(runningTests)
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
            Button {
                runAllTests(delay: previewTestDelay)
            } label: {
                Text("Play all")
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

struct ComponentDashboard_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ComponentDashboardView<ExampleComponent>(model: .init(state: ExampleComponent.states[0].state))
        }
        .navigationViewStyle(.stack)
        .previewDevice(.largestDevice)
    }
}
