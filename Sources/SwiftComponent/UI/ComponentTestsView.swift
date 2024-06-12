import Foundation
import SwiftUI

struct ComponentTestsView<ComponentType: Component>: View {

    typealias Model = ComponentType.Model
    @State var testRun = TestRun<Model>()
    @AppStorage("testPreview.showStepTitles") var showStepTitles = true
    @AppStorage("testPreview.showEvents") var showEvents = false
    @AppStorage("testPreview.showMutations") var showMutations = false
    @AppStorage("testPreview.showDependencies") var showDependencies = false
    @AppStorage("testPreview.showExpectations") var showExpectations = false
    @AppStorage("testPreview.showErrors") var showErrors = true
    @AppStorage("testPreview.showWarnings") var showWarnings = false
    @AppStorage("testPreview.showErrorDiffs") var showErrorDiffs = true
    @AppStorage("testPreview.testFilter") var testFilter: TestFilter?
    @State var collapsedTests: [String: Bool] = [:]
    @State var showViewOptions = false
    @State var testResults: [TestStepResult] = []
    @State var errorDiffVisibility: [UUID: Bool] = [:]
    @State var scrollToStep: UUID?
    @State var fixing: [UUID: Bool] = [:]
    var verticalSpacing = 10.0
    var diffAddedColor: Color = .green
    var diffRemovedColor: Color = .red
    var diffErrorExpectedColor: Color = .green
    var diffErrorRecievedColor: Color = .red
    var diffWarningRecievedColor: Color = .orange

    typealias CollapsedTests = [String: [String: Bool]]

    enum TestFilter: String {
        case passed
        case failed
        case warnings
    }

    func barColor(_ result: TestStepResult) -> Color {
        if result.success {
            if showWarnings || testFilter == .warnings, !result.assertionWarnings.isEmpty {
                return Color.orange
            } else {
                return Color.green
            }
        } else {
            return Color.red
        }
    }

    func toggleErrorDiffVisibility(_ id: UUID) {
        withAnimation {
            errorDiffVisibility[id] = !showErrorDiff(id)
        }
    }

    func showErrorDiff(_ id: UUID) -> Bool {
        errorDiffVisibility[id] ?? showErrorDiffs
    }

    func getCollapsedTests() -> [String: Bool] {
        let collapsedTests =
        UserDefaults.standard.value(forKey: "testPreview.collapsedTests") as? CollapsedTests ?? [:]
        return collapsedTests[ComponentType.Model.baseName] ?? [:]
    }

    func testIsCollapsed(_ test: Test<Model>) -> Bool {
        collapsedTests[test.testName] ?? false
    }

    func collapseTest(_ test: Test<Model>, _ collapsed: Bool) {
        withAnimation {
            collapsedTests[test.testName] = collapsed
        }

        var collapsedAllTests =
        UserDefaults.standard.value(forKey: "testPreview.collapsedTests") as? CollapsedTests ?? [:]
        collapsedAllTests[ComponentType.Model.baseName, default: [:]][test.testName] = collapsed
        UserDefaults.standard.setValue(collapsedAllTests, forKey: "testPreview.collapsedTests")
    }

    func collapseAll() {
        let allCollapsed = ComponentType.tests.reduce(true) { $0 && testIsCollapsed($1) }
        ComponentType.tests.forEach { collapseTest($0, !allCollapsed) }
    }

    func runAllTests() {
        collapsedTests = getCollapsedTests()
        Task { @MainActor in
            print("\nRunning \(ComponentType.tests.count) Tests for \(Model.baseName)")
            testRun.reset(ComponentType.tests)
            for test in ComponentType.tests {
                await runTest(test)
            }
            withAnimation {
                testRun.checkCoverage()
            }
            let passed = testRun.testState.values.filter { $0.passed }.count
            let failed = testRun.testState.values.filter { !$0.passed }.count
            var string = "\n\(failed == 0 ? "✅" : "🛑") \(Model.baseName) Tests: \(passed) passed"
            if failed > 0 {
                string += ", \(failed) failed"
            }
            print(string)
        }
    }

    @MainActor
    func runTest(_ test: Test<Model>) async {

        let state = ComponentType.state(for: test)
        testRun.startTest(test)

        let model = ViewModel<Model>(state: state, environment: test.environment)
        let result = await model.runTest(test, initialState: state, assertions: ComponentType.testAssertions, delay: 0, sendEvents: false) { result in
            testRun.addStepResult(result, test: test)
            DispatchQueue.main.async {
                //        withAnimation {
                testResults = testRun.getTestResults(for: ComponentType.tests)
                //        }
            }
        }
        testRun.completeTest(test, result: result)

        var string = ""
        let indent = "   "
        let newline = "\n"
        string += result.success ? "✅" : "🛑"
        string += " \(Model.baseName): \(test.testName)"
        for step in result.steps {
            for error in step.allErrors {
                string += newline + indent + error.error
                if let diff = error.diff {
                    string += ":" + newline + indent + diff.joined(separator: newline + indent)
                }
            }
        }
        print(string)
    }

    func setFilter(_ filter: TestFilter?) {
        withAnimation {
            if testFilter != nil, self.testFilter == filter {
                self.testFilter = nil
            } else {
                self.testFilter = filter
            }
        }
    }

    func showTest(_ test: Test<Model>) -> Bool {
        switch testFilter {
            case .none:
                return true
            case .warnings:
                return (testRun.testState[test.id]?.warningCount ?? 0) > 0
            case .passed:
                return testRun.testState[test.id]?.passed ?? false
            case .failed:
                return testRun.testState[test.id]?.failed ?? false
        }
    }

    func tap(_ result: TestStepResult) {
        scrollToStep = result.id
    }

    func fix(error: TestError, with fixit: String) {
        // read file
        guard let data = FileManager.default.contents(atPath: error.source.file.description) else { return }
        guard var sourceFile = String(data: data, encoding: .utf8) else { return }

        fixing[error.id] = true

        var lines = sourceFile.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let line = Int(error.source.line)

        // edit file
        guard line > 0, line < lines.count - 1 else { return }
        let currentLine = lines[line - 1]
        guard let currentIndentIndex = currentLine.firstIndex(where: { !$0.isWhitespace }) else { return }
        let indent = String(currentLine[..<currentIndentIndex])
        // TODO: check actual indent
        lines.insert(indent + "    " + fixit, at: line)
        sourceFile = lines.joined(separator: "\n")

        // write file
        ComponentType.writeSource(sourceFile)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            resultBar
            coverage
            Divider()
            ScrollView {
                ScrollViewReader { scrollProxy in
                    LazyVStack(spacing: 20) {
                        ForEach(ComponentType.tests, id: \.id) { test in
                            if showTest(test) {
                                testRow(test)
                                    .background(Color(white: 1))
                                    .cornerRadius(12)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12).stroke(Color(white: 0.8))
                                    }
                                //                            .shadow(color: Color(white: 0, opacity: 0.1), radius: 6)
                            }
                        }
                    }
                    .onChange(of: scrollToStep) { step in
                        if let step {
                            withAnimation {
                                scrollProxy.scrollTo(step, anchor: .top)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(white: 0.9))
            .animation(.default, value: showStepTitles)
            .animation(.default, value: showDependencies)
            .animation(.default, value: showEvents)
            .animation(.default, value: showMutations)
            .animation(.default, value: showExpectations)
            .animation(.default, value: showErrors)
            .animation(.default, value: showErrorDiffs)
            .animation(.default, value: showWarnings)
            .animation(.default, value: testFilter)
        }
        .task {
            runAllTests()
        }
    }

    @ViewBuilder
    func filterButton(_ filter: TestFilter?, color: Color, label: String, count: Int) -> some View {
        let selected = testFilter == filter
        Button(action: { setFilter(filter) }) {
            HStack {
                Text(count.description)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .fixedSize()
                    .monospacedDigit()
                Text(label)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
            }
            .font(.title2)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 6).fill(count == 0 ? Color.gray : color)
            }
            .padding(3)
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 9).stroke(.primary, lineWidth: 3)
                }
            }
        }
        .buttonStyle(.plain)
    }

    var header: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .bottom, spacing: 20) {
//                filterButton(.none, color: Color(white: 0.4), label: "All Tests", count: ComponentType.tests.count)
                filterButton(.passed, color: .green, label: "Passed", count: testRun.passedTestCount)
                filterButton(.failed, color: .red, label: "Failed", count: testRun.failedTestCount)
                filterButton(.warnings, color: .orange, label: "Improvements", count: testRun.stepWarningsCount)
                Spacer()
                HStack(spacing: 30) {
                    Button(action: { showViewOptions = true }) {
                        Text("Settings")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showViewOptions) {
                        VStack(alignment: .trailing, spacing: 12) {
                            // TODO: add tasks
                            Toggle("Show step titles", isOn: $showStepTitles)
                            Toggle("Show dependencies", isOn: showStepTitles ? $showDependencies : .constant(false))
                                .disabled(!showStepTitles)
                            Toggle("Show events", isOn: $showEvents)
                            Toggle("Show mutation diffs", isOn: $showMutations)
                            Toggle("Show expectations", isOn: $showExpectations.animation())
                            Toggle("Show assertion warnings", isOn: testFilter == .warnings ? .constant(true) : $showWarnings)
                                .disabled(testFilter == .warnings)
                            Toggle("Show errors", isOn: $showErrors)
                            Toggle("Show error diffs", isOn: showErrors ? $showErrorDiffs : .constant(false))
                                .disabled(!showErrors)
                        }
                        .padding(24)
                    }
                    Button(action: collapseAll) {
                        Text("Collapse")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .font(.headline)
                .padding(.trailing, 16)
            }
        }
        .padding()
    }

    var resultBar: some View {
        HStack(spacing: 2) {
            ForEach(testResults, id: \.id) { result in
                Button(action: { tap(result) }) {
                    barColor(result)
                }
            }
        }
        .frame(height: 12)
        .cornerRadius(6)
        .clipped()
        .padding(.horizontal)
        .padding(.bottom)
    }

    @ViewBuilder
    var coverage: some View {
        if testRun.missingCoverage.hasValues {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(testRun.missingCoverage.actions.sorted(), id: \.self) {
                        coverageBadge(type: "Action", name: $0)
                    }
                    ForEach(testRun.missingCoverage.routes.sorted(), id: \.self) {
                        coverageBadge(type: "Route", name: $0)
                    }
                    ForEach(testRun.missingCoverage.outputs.sorted(), id: \.self) {
                        coverageBadge(type: "Output", name: $0)
                    }
                }
                .padding()
            }
        }
    }

    func coverageBadge(type: String, name: String) -> some View {
        Text("\(type).\(name)")
            .foregroundColor(.white)
            .padding(8)
            .background(Color.orange)
            .cornerRadius(6)
    }

    func testRow(_ test: Test<Model>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            testHeader(test)
                .padding(16)
                .background(Color(white: 0.98))
            if !testIsCollapsed(test) {
                Divider()
                    .padding(.bottom, 8)
                if let steps = testRun.testResults[test.id] {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(steps, id: \.self) { step in
                            if let stepResult = testRun.testStepResults[step], showDependencies || stepResult.title != "Dependency" {
                                stepResultRow(stepResult, test: test)
                                    .id(step)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    func testHeader(_ test: Test<Model>) -> some View {
        Button {
            collapseTest(test, !testIsCollapsed(test))
//            Task { @MainActor in
//                await runTest(test)
//            }
        } label: {
            let testResult = testRun.getTestState(test)
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        switch testResult {
                            case .running:
                                Image(systemName: "circle")
                            case .complete(let result):
                                if result.success {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                } else {
                                    Image(systemName: "exclamationmark.octagon.fill").foregroundColor(.red)
                                }
                            case .notRun:
                                Image(systemName: "circle")
                            case .pending:
                                Image(systemName: "play.circle").foregroundColor(.gray)
                            case .failedToRun:
                                Image(systemName: "x.circle.fill").foregroundColor(.red)
                        }
                    }
                    .foregroundColor(testResult.color)
                    Text(test.testName)
                        .bold()
                        .foregroundColor(testResult.color)
                }
                .font(.title3)
                Spacer()
                switch testResult {
                    case .complete(let result):
                        Text(result.formattedDuration)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    default:
                        EmptyView()
                }
                //                if !runningTests {
                //                    Image(systemName: "play.circle")
                //                        .font(.title3)
                //                }
                collapseIcon(collapsed: testIsCollapsed(test))
                    .foregroundColor(.secondary)

            }
            .contentShape(Rectangle())
            //            .animation(nil)
        }
        .buttonStyle(.plain)
    }

    func collapseIcon(collapsed: Bool) -> some View {
        ZStack {
            Image(systemName: "chevron.right")
                .opacity(collapsed ? 1 : 0)
            Image(systemName: "chevron.down")
                .opacity(!collapsed ? 1 : 0)
        }
    }

    func stepColor(stepResult: TestStepResult, test: Test<Model>) -> Color {
        switch testRun.getTestState(test) {
            case .complete(let result):
                if result.success {
                    return .green
                } else {
                    return stepResult.success ? .secondary : .red
                }
            default: return .secondary
        }
    }

    func stepResultRow(_ stepResult: TestStepResult, test: Test<Model>) -> some View {
        HStack(alignment: .top, spacing: 0) {
            if showStepTitles {
                HStack {
//                                Group {
//                                    if stepResult.success {
//                                        Image(systemName: "checkmark.circle.fill")
//                                    } else {
//                                        Image(systemName: "x.circle.fill")
//                                    }
//                                }
                    bullet
                        .padding(4)
                        .foregroundColor(stepColor(stepResult: stepResult, test: test))
                        .padding(.trailing, 4)
                        .padding(.top, verticalSpacing)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                // groups are to fix a rare compiler type inference error
                HStack {

                    if showStepTitles {
                        HStack(spacing: 0) {
                            Text(stepResult.title)
                                .bold()
                            if let details = stepResult.details {
                                Text(": " + details)
                            }
                        }
                            .lineLimit(1)
//                            .foregroundColor(stepColor(stepResult: stepResult, test: test))
                            .foregroundColor(.testContent)
                            .padding(.top, verticalSpacing)
                    }
                    if showDependencies {
                        Spacer()
                        HStack {
                            ForEach(stepResult.coverage.dependencies.sorted(), id: \.self) { dependency in
                                Text(dependency)
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 6)
                                    .foregroundColor(.white)
                                    .background(Color.gray)
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                Group {
                    if showEvents, !stepResult.events.isEmpty {
                        stepEvents(stepResult.events)
                            .padding(.top, verticalSpacing)
                    }
                }
                Group {
                    if !showEvents, showMutations, !stepResult.mutations.isEmpty {
                        stepMutations(stepResult.mutations)
                            .padding(.top, verticalSpacing)
                    }
                }
                Group {
                    if !stepResult.children.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(stepResult.children, id: \.id) { result in
                                // AnyView fixes compiler error
                                AnyView(self.stepResultRow(result, test: test))
                            }
                        }
                    }
                }
                Group {
                    if showExpectations, !stepResult.expectations.isEmpty {
                        stepExpectations(stepResult.expectations)
                            .padding(.top, verticalSpacing)
                    }
                }
                Group {
                    if showErrors, !stepResult.errors.isEmpty {
                        stepResultErrors(stepResult.errors)
                            .padding(.top, verticalSpacing)
                    }
                }
                Group {
                    if showWarnings || testFilter == .warnings, !stepResult.assertionWarnings.isEmpty {
                        stepResultErrors(stepResult.assertionWarnings, warning: true)
                            .padding(.top, verticalSpacing)
                    }
                }
            }
        }
    }

    func stepEvents(_ events: [Event]) -> some View {
        VStack(alignment: .leading, spacing:8) {
            ForEach(events.sorted { $0.start < $1.start }) { event in
                VStack(alignment: .leading) {
                    NavigationLink {
                        ComponentEventView(event: event, allEvents: events)
                    } label: {
                        HStack {
                            //                            Text(event.type.emoji)
                            Text("Event: ") +
                            Text(event.type.title).bold() +
                            Text(" " + event.type.details)
                            Spacer()
                            Text(event.path.droppingRoot?.string ?? "")
                                .foregroundColor(.secondary)
                        }
                    }
                    switch event.type {
                        case .mutation(let mutation):
                            if showMutations {
                                mutationView(mutation)
                            }
                        default:
                            EmptyView()
                    }
                }
                .foregroundColor(.testContent)
            }
        }
    }

    func stepMutations(_ mutations: [Mutation]) -> some View {
        VStack(alignment: .leading, spacing:8) {
            ForEach(mutations, id: \.id) { mutation in
                mutationView(mutation)
            }
        }
    }

    @ViewBuilder
    func mutationView(_ mutation: Mutation) -> some View {
        if let diff = mutation.stateDiff {
            VStack(alignment: .leading) {
                diff
                    .diffText(removedColor: diffRemovedColor, addedColor: diffAddedColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .textContainer()
            .cornerRadius(8)
            .padding(.bottom, 8)
        }
    }

    func stepExpectations(_ expectations: [String]) -> some View {
        VStack(alignment: .leading, spacing:8) {
            ForEach(expectations, id: \.self) { expectation in
                HStack {
                    Text(expectation)
                }
                .foregroundColor(.testContent)
            }
        }
    }

    func stepResultErrors(_ errors: [TestError], warning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(errors, id: \.id) { error in
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: { toggleErrorDiffVisibility(error.id) }) {
                        HStack {
                            Image(systemName: warning ? "exclamationmark.triangle.fill" : "exclamationmark.octagon.fill")
                            Text(error.error)
                                .bold()
                                .padding(.vertical, 10)
                            Spacer()
                            if let fixit = error.fixit, fixing[error.id] != true {
                                Button(action: { fix(error: error, with: fixit) }) {
                                    Text("Fix")
                                        .bold()
                                        .padding(-2)
                                }
                                .buttonStyle(.bordered)
                            }
                            if error.diff != nil {
                                collapseIcon(collapsed: !showErrorDiff(error.id))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .background {
                            warning ? Color.orange : Color.red
                        }
                        .contentShape(Rectangle())
                        //                    .shadow(radius: 10)
                    }
                    .buttonStyle(.plain)
                    if showErrorDiffs, showErrorDiff(error.id), let diff = error.diff {
//                        Divider()
                        diff
                            .diffText(removedColor: warning ? diffWarningRecievedColor : diffErrorRecievedColor, addedColor: diffErrorExpectedColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textContainer()
                    }
                }
                .cornerRadius(8)
                .clipped()
            }
        }
    }

    var bullet: some View {
        Circle().frame(width: 12, height: 12)
    }
}

extension Color {

    static let testContent: Color = Color(white: 0.4)
}

extension View {

    func textContainer() -> some View {
        self
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(Color(white: 0.15))
    }
}

extension [String] {

    private func getTextLine(_ line: String, textColor: Color, removedColor: Color, addedColor: Color, multiline: Bool) -> Text {
        var line = String(line)
        var color = textColor
        var change: Bool = false
        if line.hasPrefix("+") {
            line = " " + String(line.dropFirst(1))
            color = addedColor
            change = true
        } else if line.hasPrefix("-") {
            line = " " + String(line.dropFirst(1))
            color = removedColor
            change = true
        }
        let parts = line.split(separator: ":")
        let text: Text
        let recolorPropertyNames = false
        if recolorPropertyNames, parts.count > 1, multiline {
            let property = Text(parts[0] + ":")
//                .foregroundColor(color)
                .foregroundColor(color.opacity(0.5))
//                .foregroundColor(textColor)
//                .bold()
            let rest = Text(parts.dropFirst().joined(separator: ":"))
                .foregroundColor(color)
            text = property + rest
        } else {
            text = Text(line)
                .foregroundColor(color)
        }
        if change {
//             text = text.bold()
        }
        return text
    }

    func diffText(textColor: Color = Color(white: 0.8), removedColor: Color = .red, addedColor: Color = .green) -> some View {
        var text = Text("")
        let lines = self
        for (index, line) in lines.enumerated() {
            var line = line
            if index != lines.count - 1 {
                line += "\n"
            }
            text = text + getTextLine(line, textColor: textColor, removedColor: removedColor, addedColor: addedColor, multiline: lines.count > 2)
        }
        return text.fixedSize(horizontal: false, vertical: true)
    }
}

struct ComponentTests_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ComponentTestsView<ExampleComponent>()
        }
#if os(iOS)
        .navigationViewStyle(.stack)
#endif
        .largePreview()
    }
}
