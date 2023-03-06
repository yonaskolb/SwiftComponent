import Foundation

//public struct TestExpectation<Model: ComponentModel> {
//
//    let name: String
//    let run: (Context) -> [TestError]
//    let source: Source
//
//    struct Context {
//        let store: ViewModel<Model>
//        let dependencies: DependencyValues
//        let events: [ComponentEvent]
//    }
//}
//
//extension TestStep {
//
//    func expect(_ expectation: Expectation) {
//
//    }
//}

extension TestStep {

    func addExpectation(_ expectation: Expectation, source: Source) -> Self {
        var step = self
        step.expectations.append(expectation)
        // TODO: move into proper type and use source
        return step
    }

    public func validateDependency<T>(_ error: String, _ keyPath: KeyPath<DependencyValues, T>, _ validateDependency: @escaping (T) -> Bool, file: StaticString = #file, line: UInt = #line) -> Self {
        addExpectation(.validateDependency(error: error, dependency: String(describing: T.self), validateDependency: { validateDependency($0[keyPath: keyPath]) }), source: .capture(file: file, line: line))
    }

    public func expectOutput(_ output: Model.Output, file: StaticString = #file, line: UInt = #line) -> Self {
        addExpectation(.expectOutput(output), source: .capture(file: file, line: line))
    }

    /// validate some properties on state by returning a boolean
    public func validateState(_ name: String, file: StaticString = #file, line: UInt = #line, _ validateState: @escaping (Model.State) -> Bool) -> Self {
        addExpectation(.validateState(name: name, validateState: validateState), source: .capture(file: file, line: line))
    }

    /// expect state to have certain properties set. Set any properties on the state that should be set. Any properties left out fill not fail the test
    public func expectState(file: StaticString = #file, line: UInt = #line, _ modify: @escaping (inout Model.State) -> Void) -> Self {
        addExpectation(.expectState(modify), source: .capture(file: file, line: line))
    }

    /// expect state to have a keypath set to a value
    public func expectState<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, _ value: Value, file: StaticString = #file, line: UInt = #line) -> Self {
        addExpectation(.expectState { $0[keyPath: keyPath] = value }, source: .capture(file: file, line: line))
    }

    public func expectTask(_ taskID: Model.Task, successful: Bool = true, file: StaticString = #file, line: UInt = #line) -> Self {
        addExpectation(.expectTask(taskID.taskName, successful: successful), source: .capture(file: file, line: line))
    }

    //TODO: also clear mutation assertions
    public func expectResourceTask<R>(_ keyPath: KeyPath<Model.State, Resource<R>>, successful: Bool = true, file: StaticString = #file, line: UInt = #line) -> Self {
        addExpectation(.expectTask(getResourceTaskName(keyPath), successful: successful), source: .capture(file: file, line: line))
    }

    public func expectEmptyRoute(file: StaticString = #file, line: UInt = #line) -> Self {
        addExpectation(.expectEmptyRoute, source: .capture(file: file, line: line))
    }

    public func expectRoute<Child: ComponentModel>(_ path: CasePath<Model.Route, ComponentRoute<Child>>, state: Child.State, childRoute: Child.Route? = nil, file: StaticString = #file, line: UInt = #line) -> Self {
        let componentRoute = ComponentRoute<Child>(state: state, route: childRoute)
        componentRoute.store = .init(state: state)
        return addExpectation(.expectRoute(name: Child.baseName, state: state) { route in
            path.extract(from: route)?.state
        }, source: .capture(file: file, line: line))
    }

}

extension TestStep.Expectation {

    public var title: String {
        switch self {
            case .validateState:
                return "Validate"
            case .expectState:
                return "Expect state"
            case .expectOutput:
                return "Expect output"
            case .validateDependency:
                return "Validate dependency"
            case .expectTask:
                return "Expect task"
            case .expectRoute:
                return "Expect route"
            case .expectEmptyRoute:
                return "Expect empty route"
        }
    }

    public var description: String {
        var string = title
        if let details {
            string += " \(details)"
        }
        return string
    }

    public var details: String? {
        switch self {
            case .validateState(let name, _ ):
                return name.quoted
            case .expectState(_):
                return nil
            case .expectOutput(let output):
                return getEnumCase(output).name.quoted
            case .validateDependency(_, let path, _ ):
                return path.quoted
            case .expectRoute(let name, _, _):
                return name.quoted
            case .expectEmptyRoute:
                return nil
            case .expectTask(let name, let success):
                return "\(name.quoted) \(success ? "success" : "failure")"
        }
    }
}
