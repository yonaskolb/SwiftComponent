import Foundation

public struct ComponentSnapshot<Model: ComponentModel> {
    public var name: String = "snapshot"
    public var state: Model.State
    public var environment: Model.Environment
    public var route: Model.Route?
    public var source: Source
    public var dependencies: ComponentDependencies = .init()
}

extension ComponentSnapshot {
    public init(state: Model.State, environment: Model.Environment, route: Model.Route? = nil, file: StaticString = #file, line: UInt = #line) {
        self.init(state: state, environment: environment, route: route, source: .capture(file: file, line: line))
    }

    public init(state: Model.State, environment: Model.Environment? = nil, route: Model.Route? = nil, file: StaticString = #file, line: UInt = #line) where Model.Environment: ComponentEnvironment {
        self.init(state: state, environment: environment ?? Model.Environment.preview, route: route, source: .capture(file: file, line: line))
    }
}

extension TestStep {

    public static func snapshot(_ name: String, environment: Model.Environment? = nil, file: StaticString = #file, line: UInt = #line) -> Self {
        var step = Self(title: "Snapshot", details: name, file: file, line: line) { context in
            var snapshot = ComponentSnapshot<Model>(
                state: context.state,
                environment: environment ?? context.model.environment,
                route: context.model.route,
                source: .capture(file: file, line: line)
            )
            snapshot.name = name
            context.snapshots.append(snapshot)
        }
        step.snapshots = [name]
        return step
    }
}

extension ComponentSnapshot {
    public func viewModel() -> ViewModel<Model> {
        ViewModel(state: state, environment: environment, route: route).apply(dependencies)
    }
}

extension Component {

    static var snapshotNames: [String] {
        tests.reduce([]) { $0 + $1.steps.flatMap(\.snapshots) }
    }
}

@resultBuilder
public struct SnapshotBuilder {
    public static func buildBlock<Model: ComponentModel>() -> [ComponentSnapshot<Model>] { [] }
    public static func buildBlock<Model: ComponentModel>(_ snapshots: ComponentSnapshot<Model>...) -> [ComponentSnapshot<Model>] { snapshots }
    public static func buildBlock<Model: ComponentModel>(_ snapshots: [ComponentSnapshot<Model>]) -> [ComponentSnapshot<Model>] { snapshots }
}
