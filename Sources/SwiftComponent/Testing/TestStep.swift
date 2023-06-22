import Foundation

public typealias TestStepContext<Model: ComponentModel> = TestStep<Model>
public typealias Step = TestStep

public struct TestStep<Model: ComponentModel>: Identifiable {

    public var title: String
    public var details: String?
    public var source: Source
    public let id = UUID()
    public var expectations: [TestExpectation<Model>] = []
    var dependencies: ComponentDependencies
    fileprivate var _run: (inout TestContext<Model>) async -> Void

    public init(title: String, details: String? = nil, file: StaticString, line: UInt, run: @escaping @MainActor (inout TestContext<Model>) async -> Void) {
        self.title = title
        self.details = details
        self.source = .capture(file: file, line: line)
        self._run = run
        self.dependencies = .init()
    }

    @MainActor
    public func run(_ context: inout TestContext<Model>) async {
        await _run(&context)
    }

    public var description: String {
        var string = title
        if let details {
            string += " \(details)"
        }
        return string
    }
}

extension TestStep {

    public func beforeRun(_ run: @escaping (inout TestContext<Model>) async -> Void, file: StaticString = #filePath, line: UInt = #line) -> Self {
        var step = self
        let stepRun = _run
        step._run = { context in
            await run(&context)
            await stepRun(&context)
        }
        return step
    }
}

// Type inference in builders doesn't work properly
// https://forums.swift.org/t/function-builder-cannot-infer-generic-parameters-even-though-direct-call-to-buildblock-can/35886/25
// https://forums.swift.org/t/result-builder-expressiveness-and-type-inference/56417
@resultBuilder
public struct TestStepBuilder<Model: ComponentModel> {
    public static func buildBlock() -> [TestStep<Model>] { [] }
    public static func buildBlock(_ tests: TestStep<Model>...) -> [TestStep<Model>] { tests }
    public static func buildBlock(_ tests: [TestStep<Model>]) -> [TestStep<Model>] { tests }
    public static func buildExpression(_ test: TestStep<Model>) -> TestStep<Model> { test }
}
