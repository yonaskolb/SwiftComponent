import Foundation
import Runtime

public enum TestAssertion: String, CaseIterable {
    case task
    case route
    case dependency
    case emptyRoute
    case state
    case output
    //    case mutation
}

extension Set where Element == TestAssertion {
    public static var all: Self { Self(TestAssertion.allCases) }
    public static var none: Self { Self([]) }
    public static var normal: Self { Self([
        .output,
        .task,
        .route,
        .emptyRoute,
    ]) }

}

extension TestAssertion {

    // snippet replacement <#State# > without space

    func assert<Model: ComponentModel>(events: [Event], context: inout TestContext<Model>, source: Source) -> [TestError] {
        var errors: [TestError] = []
        switch self {
        case .output:
            for event in events {
                switch event.type {
                case .output(let output):
                    let enumCase = getEnumCase(output)
                    errors.append(TestError(error: "Unexpected output \(enumCase.name.quoted)", source: source, fixit: ".expectOutput(.\(enumCase.name)\(enumCase.values.isEmpty ? "" : "(<#output#>)"))"))
                default: break
                }
            }
        case .task:
            for event in events {
                switch event.type {
                case .task(let result):
                    let taskID = (try? typeInfo(of: Model.Task.self).kind) == .enum ? ".\(result.name)" : result.name.quoted
                    let fixit = ".expectTask(\(taskID)\(result.successful ? "" : ", successful: false"))"
                    errors.append(TestError(error: "Unexpected task \(result.name.quoted)", source: source, fixit: fixit))
                default: break
                }
            }
        case .route:
            for event in events {
                switch event.type {
                case .route(let route):
                    errors.append(TestError(error: "Unexpected route \(getEnumCase(route).name.quoted)", source: source, fixit: ".expectRoute(/Model.Route.\(getEnumCase(route).name), state: <#State#>)"))
                default: break
                }
            }
        case .emptyRoute:
            for event in events {
                switch event.type {
                case .dismissRoute:
                    errors.append(TestError(error: "Unexpected empty route", source: source, fixit: ".expectEmptyRoute()"))
                default: break
                }
            }
        case .state:
            if let diff = StateDump.diff(context.state, context.model.state) {
                errors.append(.init(error: "Unexpected state", diff: diff, source: source, fixit: ".expectState(\\.<#keypath#>, <#state#>)"))
            }
        case .dependency:
            let unsetDependencies = context.testCoverage.dependencies.subtracting(context.model.dependencies.setDependencies)
            if !unsetDependencies.isEmpty {
                context.testCoverage.dependencies.subtract(unsetDependencies)
                let dependencies = unsetDependencies.sorted()
                for dependency in dependencies {
                    // TODO: add a fixit, but first allow a fixit to insert BEFORE the source line with a Position enum
                    errors.append(.init(error: "Uncontrolled use of dependency \(dependency.quoted)", source: source))
                }
            }
            
            //            case .mutation:
            //                for event in events {
            //                    switch event.type {
            //                        case .mutation(let mutation):
            //                            errors.append(TestError(error: "Unexpected mutation of \(mutation.property.quoted)", source: source))
            //                        default: break
            //                    }
            //                }
        }
        return errors
    }
}
