import Foundation

public struct TestStepResult: Identifiable {

    public var id: UUID
    public var title: String
    public var details: String?
    public var expectations: [String]
    public var events: [Event]
    public var stepErrors: [TestError]
    public var expectationErrors: [TestError]
    public var assertionErrors: [TestError]
    public var assertionWarnings: [TestError]
    public var errors: [TestError] { stepErrors + expectationErrors + assertionErrors }
    public var allErrors: [TestError] { errors + children.reduce([]) { $0 + $1.allErrors } }
    public var allWarnings: [TestError] { assertionWarnings + children.reduce([]) { $0 + $1.allWarnings } }
    public var children: [TestStepResult]
    public var success: Bool { allErrors.isEmpty }
    public var coverage: TestCoverage

    init<Model>(
        step: TestStep<Model>,
        events: [Event],
        expectationErrors: [TestError],
        assertionErrors: [TestError],
        assertionWarnings: [TestError],
        children: [TestStepResult],
        coverage: TestCoverage
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
        self.stepErrors = []
        self.coverage = coverage
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
    public var snapshots: [ComponentSnapshot<Model>]

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

public struct TestCoverage {
    public var actions: Set<String> = []
    public var outputs: Set<String> = []
    public var routes: Set<String> = []
    public var dependencies: Set<String> = []

    var hasValues: Bool { !actions.isEmpty || !outputs.isEmpty || !routes.isEmpty || !dependencies.isEmpty }

    mutating func subtract(_ coverage: TestCoverage) {
        actions.subtract(coverage.actions)
        outputs.subtract(coverage.outputs)
        routes.subtract(coverage.routes)
        dependencies.subtract(coverage.dependencies)
    }

    mutating func add(_ coverage: TestCoverage) {
        actions.formUnion(coverage.actions)
        outputs.formUnion(coverage.outputs)
        routes.formUnion(coverage.routes)
        dependencies.formUnion(coverage.dependencies)
    }
}

public struct TestError: CustomStringConvertible, Identifiable, Hashable {
    public var error: String
    public var diff: [String]?
    public let source: Source
    public var fixit: String?
    public let id = UUID()

    public var description: String {
        var string = error
        if let diff {
            string += ":\n\(diff.joined(separator: "\n"))"
        }
        return string
    }
}
