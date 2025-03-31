import Foundation

public struct ComponentSnapshot<Model: ComponentModel> {
    public var name: String = "snapshot"
    public var state: Model.State
    public var environment: Model.Environment
    public var route: Model.Route?
    public var tags: Set<String>
    public var source: Source
    public var dependencies: ComponentDependencies = .init()
}

extension ComponentSnapshot {
    public init(
        state: Model.State,
        environment: Model.Environment,
        route: Model.Route? = nil,
        tags: Set<String> = [],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        self.init(
            state: state,
            environment: environment,
            route: route,
            tags: tags,
            source: .capture(file: file, line: line)
        )
    }

    public init(
        state: Model.State, 
        environment: Model.Environment? = nil,
        route: Model.Route? = nil,
        tags: Set<String> = [],
        file: StaticString = #file,
        line: UInt = #line
    ) where Model.Environment: ComponentEnvironment {
        self.init(
            state: state,
            environment:
                environment ?? Model.Environment.preview,
            route: route,
            tags: tags,
            source: .capture(file: file, line: line)
        )
    }
}

struct TestSnapshot {
    let name: String
    let tags: Set<String>
}

extension TestStep {

    public static func snapshot(_ name: String, environment: Model.Environment? = nil, tags: Set<String> = [], file: StaticString = #file, line: UInt = #line) -> Self {
        var step = Self(title: "Snapshot", details: name, file: file, line: line) { context in
            var snapshot = ComponentSnapshot<Model>(
                state: context.state,
                environment: environment ?? context.model.environment,
                route: context.model.route,
                tags: tags,
                source: .capture(file: file, line: line)
            )
            snapshot.dependencies.apply(context.model.dependencies)
            snapshot.name = name
            context.snapshots.append(snapshot)
        }
        step.snapshots = [TestSnapshot(name: name, tags: tags)]
        return step
    }
}

extension ComponentSnapshot {
    public func viewModel() -> ViewModel<Model> {
        ViewModel(state: state, environment: environment, route: route).apply(dependencies)
    }
}

extension Component {

    static var testSnapshots: [TestSnapshot] {
        tests.reduce([]) { $0 + $1.steps.flatMap(\.snapshots) }
    }
}

@resultBuilder
public struct SnapshotBuilder<Model: ComponentModel> {
    public static func buildBlock() -> [ComponentSnapshot<Model>] { [] }

    public static func buildExpression(_ expression: ComponentSnapshot<Model>) -> [ComponentSnapshot<Model>] {
        [expression]
    }

    public static func buildExpression(_ expression: [ComponentSnapshot<Model>]) -> [ComponentSnapshot<Model>] {
        expression
    }

    public static func buildPartialBlock(first: [ComponentSnapshot<Model>]) -> [ComponentSnapshot<Model>] {
        first
    }

    public static func buildPartialBlock(accumulated: [ComponentSnapshot<Model>], next: [ComponentSnapshot<Model>]) -> [ComponentSnapshot<Model>] {
        accumulated + next
    }
}
