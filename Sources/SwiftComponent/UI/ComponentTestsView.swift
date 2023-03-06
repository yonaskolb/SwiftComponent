import Foundation
import SwiftUI

enum TestState<Model: ComponentModel> {
    case notRun
    case running
    case failedToRun(TestError)
    case complete(TestResult<Model>)
    case pending

    var errors: [TestError]? {
        switch self {
            case .complete(let result):
                let errors = result.errors
                if !errors.isEmpty { return errors}
            case .failedToRun(let error):
                return [error]
            default: break
        }
        return nil
    }

    var color: Color {
        switch self {
            case .notRun: return .accentColor
            case .running: return .gray
            case .failedToRun: return .red
            case .complete(let result): return result.success ? .green : .red
            case .pending: return .gray
        }
    }
}

struct ComponentTestsView<ComponentType: Component>: View {

    typealias Model = ComponentType.Model

    @State var testState: [String: TestState<Model>] = [:]
    @State var testResults: [String: [TestStep<Model>.ID]] = [:]
    @State var testStepResults: [TestStep<Model>.ID: TestStepResult] = [:]
    @State var showEvents = false
    @State var showDependencies = false
    @State var showExpectations = false
    @State var showErrors = true
    @State var showStepTitles = true

    func getTestState(_ test: Test<Model>) -> TestState<Model> {
        testState[test.name] ?? .notRun
    }

    func runAllTests() {
        Task { @MainActor in
            ComponentType.tests.forEach { testState[$0.name] = .pending }
            for test in ComponentType.tests {
                await runTest(test)
            }
        }
    }

    @MainActor
    func runTest(_ test: Test<Model>) async {

        guard let state = ComponentType.state(for: test) else { return }
        testState[test.name] = .running

        let model = ViewModel<Model>(state: state)
        let result = await model.runTest(test, initialState: state, assertions: ComponentType.testAssertions, delay: 0, sendEvents: false) { result in
            Task { @MainActor in
                testResults[test.name, default: []].append(result.id)
                testStepResults[result.id] = result
            }
        }
        testState[test.name] = .complete(result)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(ComponentType.tests, id: \.name) { test in
                    testRow(test)
                    Divider()
                }
            }
            //            .animation(.default)
            .padding(20)
        }
        .task {
            runAllTests()
        }
    }

    func testRow(_ test: Test<Model>) -> some View {
        VStack(alignment: .leading) {
            testHeader(test)
                .padding(.bottom, 8)
            if let steps = testResults[test.name] {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(steps, id: \.self) { step in
                        if let stepResult = testStepResults[step], showDependencies || stepResult.title != "Dependency" {
                            stepResultRow(stepResult, test: test)
                        }
                    }
                }
                .padding(.leading, 30)
            }
        }
    }

    func stepColor(stepResult: TestStepResult, test: Test<Model>) -> Color {
        switch getTestState(test) {
            case .complete(let result):
                if result.success {
                    return .green
                } else {
                    return stepResult.success ? .secondary : .red
                }
            default: return .primary
        }
    }

    func stepResultRow(_ stepResult: TestStepResult, test: Test<Model>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // groups are to fix a rare compiler type inference error
            Group {
                if showStepTitles {
                    stepTitle(stepResult, test: test)
                }
            }
            Group {
                if showEvents, !stepResult.events.isEmpty {
                    stepEvents(stepResult.events)
                        .padding(.leading, 28)
                        .padding(.top, 8)
                }
            }
            Group {
                if showExpectations, !stepResult.expectations.isEmpty {
                    stepExpectations(stepResult.expectations)
                        .padding(.leading, 28)
                        .padding(.top, 8)
                }
            }
            Group {
                if showErrors, !stepResult.errors.isEmpty {
                    stepResultErrors(stepResult.errors)
                        .padding(.leading, 28)
                        .padding(.top, 2)
                }
            }
            Group {
                if !stepResult.children.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(stepResult.children, id: \.id) { result in
                            if showDependencies || result.title != "Dependency" {
                                // AnyView fixes compiler error
                                AnyView(self.stepResultRow(result, test: test))
                            }
                        }
                    }
                    .padding(.leading, 28)
                    .padding(.top, 10)
                }
            }
        }
    }

    func stepTitle(_ stepResult: TestStepResult, test: Test<Model>) -> some View {
        HStack {
            Group {
                if stepResult.success {
                    Image(systemName: "checkmark.circle.fill")
                } else {
                    Image(systemName: "x.circle.fill")
                }
            }
            .foregroundColor(stepColor(stepResult: stepResult, test: test))

            Text(stepResult.description)
                .bold()
                .lineLimit(1)
                .foregroundColor(stepColor(stepResult: stepResult, test: test))
        }
    }

    func stepEvents(_ events: [Event]) -> some View {
        VStack(alignment: .leading, spacing:8) {
            ForEach(events.sorted { $0.start < $1.start }) { event in
                HStack {
                    //                            Text(event.type.emoji)
                    Text("Event: ") +
                    Text(event.type.title).bold() +
                    Text(" " + event.type.details)
                }
                .foregroundColor(.secondary)
            }
        }
    }

    func stepExpectations(_ expectations: [String]) -> some View {
        VStack(alignment: .leading, spacing:8) {
            ForEach(expectations, id: \.self) { expectation in
                HStack {
                    Text(expectation)
                }
                .foregroundColor(.secondary)
            }
        }
    }

    func stepResultErrors(_ errors: [TestError]) -> some View {
        ForEach(errors, id: \.id) { error in
            VStack(alignment: .leading, spacing: 4) {
                Text(error.error)
                    .foregroundColor(.red)
                if let diff = error.diff {
                    VStack(alignment: .leading, spacing: 4) {
                        diff
                            .diffText()
                            .frame(maxWidth: .infinity, alignment: .leading)
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
    }

    func testHeader(_ test: Test<Model>) -> some View {
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
                        case .complete(let result):
                            if result.success {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            } else {
                                Image(systemName: "x.circle.fill").foregroundColor(.red)
                            }
                        case .notRun:
                            Image(systemName: "circle")
                        case .pending:
                            Image(systemName: "play.circle").foregroundColor(.gray)
                        case .failedToRun:
                            Image(systemName: "x.circle.fill").foregroundColor(.red)
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
        var trimmedDiff = self
            .trimmingCharacters(in: CharacterSet([",", "(", ")"]))
        return ForEach(Array(trimmedDiff.components(separatedBy: "\n").enumerated()), id: \.0) { _, line in
            getLine(line)
        }
    }
}

struct ComponentTests_Previews: PreviewProvider {
    static var previews: some View {
        ComponentTestsView<ExampleComponent>()
    }
}
