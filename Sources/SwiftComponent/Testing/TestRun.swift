//
//  File.swift
//  
//
//  Created by Yonas Kolb on 20/3/2023.
//

import Foundation
import SwiftUI
@_implementationOnly import Runtime

struct TestRun<ComponentType: Component> {

    typealias Model = ComponentType.Model
    var testState: [Test<ComponentType>.ID: TestState] = [:]
    var testResults: [Test<ComponentType>.ID: [TestStep<Model>.ID]] = [:]
    var testStepResults: [TestStep<Model>.ID: TestStepResult] = [:]
    var snapshots: [String: ComponentSnapshot<Model>] = [:]
    var testCoverage: TestCoverage = .init()
    var missingCoverage: TestCoverage = .init()
    var totalCoverage: TestCoverage = .init()

    var passedStepCount: Int {
        testStepResults.values.filter { $0.success }.count
    }

    var failedStepCount: Int {
        testStepResults.values.filter { !$0.success }.count
    }

    var totalStepCount: Int {
        testStepResults.values.count
    }

    var passedTestCount: Int {
        testState.values.filter { $0.passed }.count
    }

    var failedTestCount: Int {
        testState.values.filter { $0.failed }.count
    }

    var stepWarningsCount: Int {
        testState.values.reduce(0) { $0 + $1.warningCount }
    }

    func getTestState(_ test: Test<ComponentType>) -> TestState {
        testState[test.id] ?? .notRun
    }

    mutating func reset(_ tests: [Test<ComponentType>]) {
        testState = [:]
        testResults = [:]
        testStepResults = [:]
        for test in tests {
            testState[test.id] = .pending
        }
    }

    mutating func startTest(_ test: Test<ComponentType>) {
        testState[test.id] = .running
        testResults[test.id] = []
    }

    mutating func addStepResult(_ result: TestStepResult, test: Test<ComponentType>) {
        testResults[test.id, default: []].append(result.id)
        testStepResults[result.id] = result
    }

    mutating func completeTest(_ test: Test<ComponentType>, result: TestResult<Model>) {
        testState[test.id] = .complete(result)
        for snapshot in result.snapshots {
            snapshots[snapshot.name] = snapshot
        }
    }

    mutating func checkCoverage() {
        var testCoverage: TestCoverage = .init()
        var missingCoverage: TestCoverage = .init()
        var totalCoverage: TestCoverage = .init()

        for stepResult in testStepResults.values {
            testCoverage.add(stepResult.coverage)
        }

        func checkCovereage<ModelType>(_ keyPath: WritableKeyPath<TestCoverage, Set<String>>, type: ModelType.Type) {
            if let typeInfo = try? typeInfo(of: type), typeInfo.kind == .enum {
                totalCoverage[keyPath: keyPath] = Set(typeInfo.cases.map(\.name))
            }
        }
        checkCovereage(\.actions, type: Model.Action.self)
        checkCovereage(\.outputs, type: Model.Output.self)
        checkCovereage(\.routes, type: Model.Route.self)
        
        missingCoverage = totalCoverage
        missingCoverage.subtract(testCoverage)
        self.missingCoverage = missingCoverage
        self.testCoverage = testCoverage
        self.totalCoverage = totalCoverage
    }

    func getTestResults(for tests: [Test<ComponentType>]) -> [TestStepResult] {
        var results: [TestStepResult] = []
        for test in tests {
            let steps = testResults[test.id] ?? []
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
