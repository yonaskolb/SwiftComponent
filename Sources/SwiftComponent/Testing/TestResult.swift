import Foundation

public struct TestStepResult: Identifiable {

    public var id: UUID
    public var title: String
    public var details: String?
    public var expectations: [String]
    public var events: [Event]
    public var errors: [TestError]
    public var allErrors: [TestError] {
        errors + children.reduce([]) { $0 + $1.errors }
    }
    public var children: [TestStepResult]
    public var success: Bool { allErrors.isEmpty }

    init<Model>(step: TestStep<Model>, events: [Event], errors: [TestError], children: [TestStepResult]) {
        self.id = step.id
        self.title = step.title
        self.details = step.details
        self.expectations = step.expectations.map(\.description)
        self.events = events
        self.errors = errors
        self.children = children
    }

    public var description: String {
        var string = title
        if let details {
            string += ".\(details)"
        }
        return string
    }
}

public struct TestResult<Model: ComponentModel> {
    public let steps: [TestStepResult]
    public var success: Bool { errors.isEmpty && steps.allSatisfy(\.success) }
    public var stepErrors: [TestError] { steps.reduce([]) { $0 + $1.errors } }
    public var errors: [TestError] { stepErrors }
}

public struct TestError: CustomStringConvertible, Identifiable, Hashable {
    public var error: String
    public var diff: String?
    public let source: Source
    public let id = UUID()

    public var description: String {
        var string = error
        if let diff {
            string += ":\n\(diff)"
        }
        return string
    }
}
