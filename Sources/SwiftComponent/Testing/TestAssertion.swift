import Foundation
import Runtime

extension [TestAssertion] {

    public static var none: Self { [] }

    public static var all: Self { [
        OutputTestAssertion(),
        TaskTestAssertion(),
        RouteTestAssertion(),
        EmptyRouteTestAssertion(),
        StateTestAssertion(),
        DependencyTestAssertion(),
    ] }

    public static var standard: Self { [
        OutputTestAssertion(),
        TaskTestAssertion(),
        RouteTestAssertion(),
        EmptyRouteTestAssertion(),
    ] }
}

public protocol TestAssertion {

    var id: String { get }
    @MainActor
    func assert<Model: ComponentModel>(context: inout TestAssertionContext<Model>)
}

public extension TestAssertion {

    var id: String { String(describing: Self.self)}
}

public struct TestAssertionContext<Model: ComponentModel> {
    public let events: [Event]
    public let source: Source
    public var testContext: TestContext<Model>
    public var errors: [TestError] = []
    public var stepID: UUID
}

// snippet replacement for copy and pasting: "<#State# >" without space

/// asserts all outputs have been expected
struct OutputTestAssertion: TestAssertion {

    func assert<Model: ComponentModel>(context: inout TestAssertionContext<Model>) {
        for event in context.events {
            switch event.type {
            case .output(let output):
                let enumCase = getEnumCase(output)
                context.errors.append(TestError(error: "Unexpected output \(enumCase.name.quoted)", source: context.source, fixit: ".expectOutput(.\(enumCase.name)\(enumCase.values.isEmpty ? "" : "(<#output#>)"))"))
            default: break
            }
        }
    }
}

/// asserts all tasks have been expected
struct TaskTestAssertion: TestAssertion {

    func assert<Model: ComponentModel>(context: inout TestAssertionContext<Model>) {
        for event in context.events {
            switch event.type {
            case .task(let result):
                let taskID = (try? typeInfo(of: Model.Task.self).kind) == .enum ? ".\(result.name)" : result.name.quoted
                let fixit = ".expectTask(\(taskID)\(result.successful ? "" : ", successful: false"))"
                context.errors.append(TestError(error: "Unexpected task \(result.name.quoted)", source: context.source, fixit: fixit))
            default: break
            }
        }
    }
}

/// asserts all routes have been expected
struct RouteTestAssertion: TestAssertion {

    func assert<Model: ComponentModel>(context: inout TestAssertionContext<Model>) {
        for event in context.events {
            switch event.type {
            case .route(let route):
                context.errors.append(TestError(error: "Unexpected route \(getEnumCase(route).name.quoted)", source: context.source, fixit: ".expectRoute(/Model.Route.\(getEnumCase(route).name), state: <#State#>)"))
            default: break
            }
        }
    }
}

/// asserts all routes have been expected
struct EmptyRouteTestAssertion: TestAssertion {

    func assert<Model: ComponentModel>(context: inout TestAssertionContext<Model>) {
        for event in context.events {
            switch event.type {
            case .dismissRoute:
                context.errors.append(TestError(error: "Unexpected empty route", source: context.source, fixit: ".expectEmptyRoute()"))
            default: break
            }
        }
    }
}

/// asserts all state mutations have been expected
struct StateTestAssertion: TestAssertion {

    func assert<Model: ComponentModel>(context: inout TestAssertionContext<Model>) {
        if let diff = StateDump.diff(context.testContext.state, context.testContext.model.state) {
            context.errors.append(.init(error: "Unexpected state", diff: diff, source: context.source, fixit: ".expectState(\\.<#keypath#>, <#state#>)"))
        }
    }
}

/// asserts all used dependency have been expected
struct DependencyTestAssertion: TestAssertion {

    func assert<Model: ComponentModel>(context: inout TestAssertionContext<Model>) {
        var setDependencies = context.testContext.model.dependencies.setDependencies
        // make sure if a dependency path is accessed but the whole dependency is overriden that counts as being set
        setDependencies.formUnion(Set(setDependencies.map {
            $0.components(separatedBy: ".").first!
        }))
        let unsetDependencies = context.testContext.testCoverage.dependencies.subtracting(setDependencies)
        if !unsetDependencies.isEmpty {
            context.testContext.testCoverage.dependencies.subtract(unsetDependencies)
            let dependencies = unsetDependencies.sorted()
            for dependency in dependencies {
                // TODO: add a fixit, but first allow a fixit to insert BEFORE the source line with a Position enum
                context.errors.append(.init(error: "Uncontrolled use of dependency \(dependency.quoted)", source: context.source))
            }
        }
    }
}
