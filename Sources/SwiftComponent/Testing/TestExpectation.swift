import Foundation

public struct TestExpectation<Model: ComponentModel> {

    public let title: String
    public let details: String?
    public let source: Source
    let run: (inout Context) -> Void

    public var description: String {
        var string = title
        if let details {
            string += " \(details)"
        }
        return string
    }

    public struct Context {
        var testContext: TestContext<Model>
        let source: Source
        var events: [Event]
        var errors: [TestError] = []
        public var model: ViewModel<Model> { testContext.model }

        public mutating func findEventValue<T>(_ find: (Event) -> T?) -> T? {
            for (index, event) in events.enumerated() {
                if let eventValue = find(event) {
                    events.remove(at: index)
                    return eventValue
                }
            }
            return nil
        }

        public mutating func error(_ error: String, diff: [String]? = nil) {
            errors.append(TestError(error: error, diff: diff, source: source))
        }
    }
}

extension TestStep {

    public func addExpectation(title: String, details: String? = nil, file: StaticString, line: UInt, run: @escaping (inout TestExpectation<Model>.Context) -> Void) -> Self {
        var step = self
        let expectation = TestExpectation<Model>(title: title, details: details, source: .capture(file: file, line: line), run: run)
        step.expectations.append(expectation)
        return step
    }
}
