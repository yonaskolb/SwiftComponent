//
//  File.swift
//  
//
//  Created by Yonas Kolb on 20/3/2023.
//

import Foundation
import SwiftUI

struct TestRun<Model: ComponentModel> {

    var testState: [String: TestState] = [:]
    var testResults: [String: [TestStep<Model>.ID]] = [:]
    var testStepResults: [TestStep<Model>.ID: TestStepResult] = [:]

    var passedTestCount: Int {
        testState.values.filter { $0.passed }.count
    }

    var failedTestCount: Int {
        testState.values.filter { $0.failed }.count
    }

    var stepWarningsCount: Int {
        testState.values.reduce(0) { $0 + $1.warningCount }
    }

    func getTestState(_ test: Test<Model>) -> TestState {
        testState[test.name] ?? .notRun
    }

    mutating func reset(_ tests: [Test<Model>]) {
        testState = [:]
        testResults = [:]
        testStepResults = [:]
        for test in tests {
            testState[test.name] = .pending
        }
    }

    mutating func startTest(_ test: Test<Model>) {
        testState[test.name] = .running
        testResults[test.name] = []
    }

    mutating func addStepResult(_ result: TestStepResult, test: Test<Model>) {
        testResults[test.name, default: []].append(result.id)
        testStepResults[result.id] = result
    }

    mutating func completeTest(_ test: Test<Model>, result: TestResult<Model>) {
        testState[test.name] = .complete(result)
    }

    func getTestResults(for tests: [Test<Model>]) -> [TestStepResult] {
        var results: [TestStepResult] = []
        for test in tests {
            let steps = testResults[test.name] ?? []
            for stepID in steps {
                if let result = testStepResults[stepID] {
                    results.append(contentsOf: getTestResults(for: result))
                }
            }
        }
        return results
    }

    private func getTestResults(for testResult: TestStepResult) -> [TestStepResult] {
        var results: [TestStepResult] = [testResult]
        for child in testResult.children {
            results.append(contentsOf: getTestResults(for: child))
        }
        return results
    }

    enum TestState {
        case notRun
        case running
        case failedToRun(TestError)
        case complete(TestResult<Model>)
        case pending

        var passed: Bool {
            switch self {
                case .complete(let result):
                    return result.success
                default:
                    return false
            }
        }

        var failed: Bool {
            switch self {
                case .complete(let result):
                    return !result.success
                case .failedToRun:
                    return true
                default:
                    return false
            }
        }

        var warningCount: Int {
            switch self {
                case .complete(let result):
                    return result.steps.reduce(0) { $0 + $1.allWarnings.count  }
                default:
                    return 0
            }
        }

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
}
