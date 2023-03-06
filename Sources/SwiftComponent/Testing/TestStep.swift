import Foundation

public typealias TestStepContext<Model: ComponentModel> = TestStep<Model>

public struct TestStep<Model: ComponentModel>: Identifiable {

    public var title: String
    public var details: String?
    public var source: Source
    public let id = UUID()
    public var expectations: [TestExpectation<Model>] = []
    private var _run: (inout TestContext<Model>) async -> Void

    public init(title: String, details: String? = nil, file: StaticString = #file, line: UInt = #line, run: @escaping @MainActor (inout TestContext<Model>) async -> Void) {
        self.init(title: title, details: details, source: .capture(file: file, line: line), run: run)
    }

    init(title: String, details: String? = nil, source: Source, run: @escaping @MainActor (inout TestContext<Model>) async -> Void) {
        self.title = title
        self.details = details
        self.source = source
        self._run = run
    }

    @MainActor
    public func run(_ context: inout TestContext<Model>) async {
        await _run(&context)
    }

    public var description: String {
        var string = title
        if let details {
            string += ".\(details)"
        }
        return string
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
    public static func buildArray(_ tests: [[TestStep<Model>]]) -> [TestStep<Model>] { Array(tests.joined()) }
}
