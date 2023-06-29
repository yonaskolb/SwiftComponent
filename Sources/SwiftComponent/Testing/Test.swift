import Foundation

public struct Test<Model: ComponentModel>: Identifiable {

    public init(_ name: String? = nil, assertions: Set<TestAssertion>? = nil, file: StaticString = #filePath, line: UInt = #line, @TestStepBuilder<Model> _ steps: () -> [TestStep<Model>]) where Model.State == Void, Model.Environment: ComponentEnvironment {
        self.init(name, state: .state(()), assertions: assertions, environment: Model.Environment.preview, file: file, line: line, steps)
    }

    public init(_ name: String? = nil, assertions: Set<TestAssertion>? = nil, environment: Model.Environment, file: StaticString = #filePath, line: UInt = #line, @TestStepBuilder<Model> _ steps: () -> [TestStep<Model>]) where Model.State == Void {
        self.init(name, state: .state(()), assertions: assertions, environment: environment, file: file, line: line, steps)
    }

    public init(_ name: String? = nil, state: Model.State, assertions: Set<TestAssertion>? = nil, file: StaticString = #filePath, line: UInt = #line, @TestStepBuilder<Model> _ steps: () -> [TestStep<Model>]) where Model.Environment: ComponentEnvironment {
        self.init(name, state: .state(state), assertions: assertions, environment: Model.Environment.preview, file: file, line: line, steps)
    }

    public init(_ name: String? = nil, state: Model.State, assertions: Set<TestAssertion>? = nil, environment: Model.Environment, file: StaticString = #filePath, line: UInt = #line, @TestStepBuilder<Model> _ steps: () -> [TestStep<Model>]) {
        self.init(name, state: .state(state), assertions: assertions, environment: environment, file: file, line: line, steps)
    }

    public init(_ name: String? = nil, assertions: Set<TestAssertion>? = nil, file: StaticString = #filePath, line: UInt = #line, @TestStepBuilder<Model> _ steps: () -> [TestStep<Model>]) where Model.Environment: ComponentEnvironment {
        self.init(name, state: .preview, assertions: assertions, environment: Model.Environment.preview, file: file, line: line, steps)
    }

    public init(_ name: String? = nil, assertions: Set<TestAssertion>? = nil, environment: Model.Environment, file: StaticString = #filePath, line: UInt = #line, @TestStepBuilder<Model> _ steps: () -> [TestStep<Model>]) {
        self.init(name, state: .preview, assertions: assertions, environment: environment, file: file, line: line, steps)
    }

    init(_ name: String? = nil, state: TestState, assertions: Set<TestAssertion>? = nil, environment: Model.Environment, file: StaticString = #filePath, line: UInt = #line, @TestStepBuilder<Model> _ steps: () -> [TestStep<Model>]) {
        self.name = name
        self.state = state
        self.environment = environment
        self.assertions = assertions
        self.source = .capture(file: file, line: line)
        self.steps = steps()
        self.dependencies = ComponentDependencies()
    }

    public enum TestState {
        case state(Model.State)
        case preview
    }

    public var name: String?
    public var index: Int = 0
    public var testName: String { name ?? (index == 0 ? "Test" : "Test \(index + 1)") }
    public var id: String { testName }
    public var state: TestState
    public var environment: Model.Environment
    public var steps: [TestStep<Model>]
    public let source: Source
    public let assertions: Set<TestAssertion>?
    public var dependencies: ComponentDependencies
}

@resultBuilder
public struct TestBuilder<Model: ComponentModel> {
    public static func buildBlock() -> [Test<Model>] { [] }
    public static func buildBlock(_ tests: Test<Model>...) -> [Test<Model>] { addIndexes(tests) }
    public static func buildBlock(_ tests: [Test<Model>]) -> [Test<Model>] { addIndexes(tests) }
    public static func buildExpression(_ test: Test<Model>) -> Test<Model> { test }

    static func addIndexes(_ tests: [Test<Model>]) -> [Test<Model>] {
        tests.enumerated().map { index, test in
            var test = test
            test.index = index
            return test
        }
    }
}
