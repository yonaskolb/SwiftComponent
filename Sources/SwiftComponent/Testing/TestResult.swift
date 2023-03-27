import Foundation

public struct TestStepResult: Identifiable {

    public var id: UUID
    public var title: String
    public var details: String?
    public var expectations: [String]
    public var events: [Event]
    public var expectationErrors: [TestError]
    public var assertionErrors: [TestError]
    public var assertionWarnings: [TestError]
    public var errors: [TestError] { expectationErrors + assertionErrors }
    public var allErrors: [TestError] {
        errors + children.reduce([]) { $0 + $1.allErrors }
    }
    public var children: [TestStepResult]
    public var success: Bool { allErrors.isEmpty }

    init<Model>(
        step: TestStep<Model>,
        events: [Event],
        expectationErrors: [TestError],
        assertionErrors: [TestError],
        assertionWarnings: [TestError],
        children: [TestStepResult]
    ) {
        self.id = step.id
        self.title = step.title
        self.details = step.details
        self.expectations = step.expectations.map(\.description)
        self.events = events
        self.expectationErrors = expectationErrors
        self.assertionErrors = assertionErrors
        self.assertionWarnings = assertionWarnings
        self.children = children
    }

    public var description: String {
        var string = title
        if let details {
            string += " \(details)"
        }
        return string
    }

    public var mutations: [Mutation] {
        events.compactMap { event in
            switch event.type {
                case .mutation(let mutation):
                    return mutation
                default:
                    return nil
            }
        }
    }
}

public struct TestResult<Model: ComponentModel> {
    public var start: Date
    public var end: Date
    public var steps: [TestStepResult]
    public var success: Bool { errors.isEmpty && steps.allSatisfy(\.success) }
    public var stepErrors: [TestError] { steps.reduce([]) { $0 + $1.errors } }
    public var errors: [TestError] { stepErrors }

    public var duration: TimeInterval {
        end.timeIntervalSince1970 - start.timeIntervalSince1970
    }

    public var formattedDuration: String {
        let seconds = duration
        if seconds < 2 {
            return Int(seconds*1000).formatted(.number) + " ms"
        } else {
            return (start ..< end).formatted(.components(style: .abbreviated))
        }
    }
}

public struct TestError: CustomStringConvertible, Identifiable, Hashable {
    public var error: String
    public var diff: [String]?
    public let source: Source
    public let id = UUID()

    public var description: String {
        var string = error
        if let diff {
            string += ":\n\(diff.joined(separator: "\n"))"
        }
        return string
    }
}
