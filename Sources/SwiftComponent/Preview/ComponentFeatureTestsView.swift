//
//  File.swift
//  
//
//  Created by Yonas Kolb on 9/11/2022.
//

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

struct ComponentFeatureTestsView<Feature: ComponentFeature>: View {

    @State var testState: [String: TestState<Feature.Model>] = [:]
    @State var testResults: [String: [TestStep<Feature.Model>.ID]] = [:]
    @State var testStepResults: [TestStep<Feature.Model>.ID: TestStepResult<Feature.Model>] = [:]
    @State var showEvents = true

    func getTestState(_ test: Test<Feature.Model>) -> TestState<Feature.Model> {
        testState[test.name] ?? .notRun
    }

    func runAllTests() {
        Task { @MainActor in
            Feature.tests.forEach { testState[$0.name] = .pending }
            for test in Feature.tests {
                await runTest(test)
            }
        }
    }

    @MainActor
    func runTest(_ test: Test<Feature.Model>) async {

        guard let state = Feature.state(for: test) else  { return }
        testState[test.name] = .running

        let viewModel = ViewModel<Feature.Model>(state: state)
        let result = await viewModel.runTest(test, initialState: state, delay: 0, sendEvents: false) { result in
            Task { @MainActor in
                testResults[test.name, default: []].append(result.id)
                testStepResults[result.id] = result
            }
        }
        testState[test.name] = .complete(result)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 30) {
                ForEach(Feature.tests, id: \.name) { test in
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

    func testRow(_ test: Test<Feature.Model>) -> some View {
        VStack(alignment: .leading) {
            testHeader(test)
                .padding(.bottom, 8)
            if let steps = testResults[test.name] {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(steps, id: \.self) { step in
                        if let stepResult = testStepResults[step] {
                            stepResultRow(stepResult, test: test)
                        }
                    }
                }
                .padding(.leading, 30)
            }
            switch getTestState(test) {
                case .complete(let result):
                    if !result.assertionErrors.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(result.assertionErrors, id: \.error) { error in
                                HStack {
                                    Image(systemName: "x.circle.fill")
                                    Text("Assertion: ")
                                        .bold() +
                                    Text(error.error)
                                }
                                .foregroundColor(.red)
                                .padding(.leading, 30)
                            }
                        }
                        .padding(.top, 2)
                    }
                    default: EmptyView()
            }
        }
    }

    func stepColor(stepResult: TestStepResult<Feature.Model>, test: Test<Feature.Model>) -> Color {
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

    func stepResultRow(_ stepResult: TestStepResult<Feature.Model>, test: Test<Feature.Model>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Group {
                    if stepResult.success {
                        Image(systemName: "checkmark.circle.fill")
                    } else {
                        Image(systemName: "x.circle.fill")
                    }
                }
                .foregroundColor(stepColor(stepResult: stepResult, test: test))

                HStack(spacing: 0) {
                    Text(stepResult.step.title)
                        .bold()
                    if let details = stepResult.step.details {
                        Text(": \(details)")
                            .lineLimit(1)
                    }
                }
                .foregroundColor(stepColor(stepResult: stepResult, test: test))
            }
            if showEvents, !stepResult.events.isEmpty {
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
                .padding(.leading, 28)
                .padding(.top, 2)
            }
        }
    }

    func testHeader(_ test: Test<Feature.Model>) -> some View {
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

struct ComponentFeatureTests_Previews: PreviewProvider {
    static var previews: some View {
        ComponentFeatureTestsView<ExamplePreview>()
    }
}
