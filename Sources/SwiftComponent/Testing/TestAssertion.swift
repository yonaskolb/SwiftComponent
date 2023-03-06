import Foundation

public enum TestAssertion: String, CaseIterable {
    case output
    case task
    case route
    case mutation
    case dependency
    case emptyRoute
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

    func assert(events: [Event], source: Source) -> [TestError] {
        var errors: [TestError] = []
        switch self {
            case .output:
                for event in events {
                    switch event.type {
                        case .output(let output):
                            errors.append(TestError(error: "Unexpected output \(getEnumCase(output).name.quoted)", source: source))
                        default: break
                    }
                }
            case .task:
                for event in events {
                    switch event.type {
                        case .task(let result):
                            errors.append(TestError(error: "Unexpected task \(result.name.quoted)", source: source))
                        default: break
                    }
                }
            case .route:
                for event in events {
                    switch event.type {
                        case .route(let route):
                            errors.append(TestError(error: "Unexpected route \(getEnumCase(route).name.quoted)", source: source))
                        default: break
                    }
                }
            case .emptyRoute:
                for event in events {
                    switch event.type {
                        case .dismissRoute:
                            errors.append(TestError(error: "Unexpected empty route", source: source))
                        default: break
                    }
                }
            case .mutation:
                for event in events {
                    switch event.type {
                        case .mutation(let mutation):
                            errors.append(TestError(error: "Unexpected mutation of \(mutation.property.quoted)", source: source))
                        default: break
                    }
                }
            case .dependency: break
        }
        return errors
    }
}
