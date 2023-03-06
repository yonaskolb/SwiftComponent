import Foundation

public struct Test<Model: ComponentModel> {

    public init(_ name: String, state: Model.State, appear: Bool = false, assertions: Set<TestAssertion>? = nil, file: StaticString = #file, line: UInt = #line, @TestStepBuilder<Model> _ steps: () -> [TestStep<Model>]) {
        self.name = name
        self.state = state
        self.appear = appear
        self.assertions = assertions
        self.source = .capture(file: file, line: line)
        self.steps = steps()
    }

    public init(_ name: String, stateName: String, appear: Bool = false, assertions: Set<TestAssertion>? = nil, file: StaticString = #file, line: UInt = #line, @TestStepBuilder<Model> _ steps: () -> [TestStep<Model>]) {
        self.name = name
        self.stateName = stateName
        self.appear = appear
        self.assertions = assertions
        self.source = .capture(file: file, line: line)
        self.steps = steps()
    }

    public var name: String
    public var state: Model.State?
    public var stateName: String?
    public var steps: [TestStep<Model>]
    public var appear: Bool
    public let source: Source
    public let assertions: Set<TestAssertion>?
}

@resultBuilder
public struct TestBuilder {
    public static func buildBlock<ComponentType: ComponentModel>() -> [Test<ComponentType>] { [] }
    public static func buildBlock<ComponentType: ComponentModel>(_ tests: Test<ComponentType>...) -> [Test<ComponentType>] { tests }
    public static func buildBlock<ComponentType: ComponentModel>(_ tests: [Test<ComponentType>]) -> [Test<ComponentType>] { tests }
}
