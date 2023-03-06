import Foundation

public enum TestAssertion: String, CaseIterable {
    case output
    case task
    case route
    case mutation
    case dependency
}

extension Set where Element == TestAssertion {
    public static var all: Self { Self(TestAssertion.allCases) }
    public static var none: Self { Self([]) }
    public static var normal: Self { Self([
        .output,
        .task,
        .route,
    ]) }

}

extension [TestAssertion] {
    func assert(events: [Event], source: Source) -> [TestError] {
        var errors: [TestError] = []
        for assertion in self {
            switch assertion {
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
        }
        return errors
    }
}
