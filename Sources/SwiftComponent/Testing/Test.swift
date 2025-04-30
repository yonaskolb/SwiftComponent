import Foundation

public struct Test<ComponentType: Component>: Identifiable {

    public typealias Model = ComponentType.Model
    
    public init(_ name: String? = nil, assertions: [TestAssertion]? = nil, environment: Model.Environment? = nil, file: StaticString = #filePath, line: UInt = #line, @TestStepBuilder<Model> _ steps: () -> [TestStep<Model>]) where Model.State == Void {
        self.init(name, state: (), assertions: assertions, environment: environment ?? ComponentType.preview.environment.copy(), file: file, line: line, steps)
    }

    public init(_ name: String? = nil, state: Model.State, assertions: [TestAssertion]? = nil, environment: Model.Environment? = nil, file: StaticString = #filePath, line: UInt = #line, @TestStepBuilder<Model> _ steps: () -> [TestStep<Model>]) {
        self.init(name, state: state, assertions: assertions, environment: environment ?? ComponentType.preview.environment.copy(), file: file, line: line, steps)
    }
    
    public init(_ name: String? = nil, assertions: [TestAssertion]? = nil, environment: Model.Environment? = nil, file: StaticString = #filePath, line: UInt = #line, @TestStepBuilder<Model> _ steps: () -> [TestStep<Model>]) {
        self.init(name, state: ComponentType.preview.state, assertions: assertions, environment: environment ?? ComponentType.preview.environment.copy(), file: file, line: line, steps)
    }

    public init(_ name: String? = nil, state: Model.State, assertions: [TestAssertion]? = nil, environment: Model.Environment, file: StaticString = #filePath, line: UInt = #line, @TestStepBuilder<Model> _ steps: () -> [TestStep<Model>]) {
        self.name = name
        self.state = state
        self.environment = environment
        self.assertions = assertions
        self.source = .capture(file: file, line: line)
        self.steps = steps()
        self.dependencies = ComponentDependencies()
    }

    public var name: String?
    public var index: Int = 0
    public var testName: String { name ?? (index == 0 ? "Test" : "Test \(index + 1)") }
    public var id: String { testName }
    public var state: Model.State
    public var environment: Model.Environment
    public var steps: [TestStep<Model>]
    public let source: Source
    public let assertions: [TestAssertion]?
    public var dependencies: ComponentDependencies
}

@resultBuilder
public struct TestBuilder<ComponentType: Component> {
    public static func buildBlock() -> [Test<ComponentType>] { [] }
    public static func buildBlock(_ tests: Test<ComponentType>...) -> [Test<ComponentType>] { addIndexes(tests) }
    public static func buildBlock(_ tests: [Test<ComponentType>]) -> [Test<ComponentType>] { addIndexes(tests) }
    public static func buildExpression(_ test: Test<ComponentType>) -> Test<ComponentType> { test }

    static func addIndexes(_ tests: [Test<ComponentType>]) -> [Test<ComponentType>] {
        tests.enumerated().map { index, test in
            var test = test
            test.index = index
            return test
        }
    }
}
