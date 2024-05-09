import Foundation
import SwiftUI

public struct ModelConnection<From: ComponentModel, To: ComponentModel> {

    let id = UUID()
    var output: OutputHandler<From, To>
    var environment: @MainActor (From) -> To.Environment
    var action: ActionHandler<From, To>?

    public init(output: OutputHandler<From, To>, environment: @MainActor @escaping (From) -> To.Environment) {
        self.output = output
        self.environment = environment
    }

    public init() where To.Output == Never, From.Environment == To.Environment {
        self.init(output: .ignore, environment: { $0.environment })
    }

    public init(environment: @escaping (From) -> To.Environment) where To.Output == Never {
        self.init(output: .ignore, environment: environment)
    }

    public init(output: OutputHandler<From, To>) where From.Environment == To.Environment {
        self.init(output: output, environment: { $0.environment })
    }

    public init(_ output: @MainActor @escaping (ConnectionOutputContext<From, To>) async -> Void) where From.Environment == To.Environment {
        self.init(output: .handle(output), environment: { $0.environment })
    }

    @MainActor
    func connect(from: ComponentStore<From>, state: ScopedState<From.State, To.State>, id stateID: AnyHashable? = nil) -> ComponentStore<To> {
        let connectionID = ConnectionID(connectionID: self.id, stateID: stateID)
        if let existingStore = from.children[connectionID] as? ComponentStore<To> {
            return existingStore
        }
        var childStore = from.scope(
            state: state,
            environment: self.environment(from.model),
            output: self.output
        )

        from.children[connectionID] = childStore

        if let actionHandler = self.action {
            childStore = childStore
                .onAction { @MainActor action, _ in
                    switch actionHandler {
                    case .output(let toOutput):
                        let output = toOutput(action)
                        from.output(output, source: .capture())
                    case .input(let toInput):
                        let input = toInput(action)
                        from.processInput(input, source: .capture())
                    case .handle(let handler):
                        from.addTask {
                            await handler((action: action, model: from.model))
                        }
                    }
                }
        }

        return childStore
    }

    func onAction(_ handle: @MainActor @escaping (ConnectionActionContext<From, To>) -> Void) -> Self {
        var copy = self
        copy.action = .handle(handle)
        return copy
    }
}

public typealias ConnectionOutputContext<Parent: ComponentModel, Child: ComponentModel> = (output: Child.Output, model: Parent)
public typealias ConnectionActionContext<Parent: ComponentModel, Child: ComponentModel> = (action: Child.Action, model: Parent)

struct ConnectionID: Hashable {
    let connectionID: UUID
    let stateID: AnyHashable?
}

extension ViewModel {

    @MainActor
    public func connect<Child: ComponentModel>(to connection: KeyPath<Model, ModelConnection<Model, Child>>, state: Child.State) -> ViewModel<Child> {
        connect(to: connection, state: .value(state))
    }

    @MainActor
    public func connect<Child: ComponentModel>(to connection: KeyPath<Model, ModelConnection<Model, Child>>, state: Binding<Child.State>) -> ViewModel<Child> {
        connect(to: connection, state: .binding(state))
    }

    @MainActor
    public func connect<Child: ComponentModel>(to connection: KeyPath<Model, ModelConnection<Model, Child>>, state: WritableKeyPath<Model.State, Child.State>) -> ViewModel<Child> {
        connect(to: connection, state: .keyPath(state))
    }

    @MainActor
    public func connect<Child: ComponentModel>(to connection: KeyPath<Model, ModelConnection<Model, Child>>, state: ScopedState<Model.State, Child.State>) -> ViewModel<Child> {
        let connection = store.model![keyPath: connection]
        return self.connect(to: connection, state: state)
    }

    @MainActor
    public func connect<Child: ComponentModel>(to connection: ModelConnection<Model, Child>, state: ScopedState<Model.State, Child.State>) -> ViewModel<Child> {
        let store = connection.connect(from: store, state: state)
        let viewModel = store.viewModel()
        return viewModel
    }
}

extension ComponentModel {

    public func connection<To: ComponentModel>(_ connection: KeyPath<Self, ModelConnection<Self, To>>, state: ScopedState<State, To.State>) -> To {
        let connection = self[keyPath: connection]
        return self.connection(connection, state: state)
    }

    public func connection<To: ComponentModel>(_ connection: ModelConnection<Self, To>, state: ScopedState<State, To.State>) -> To {
        let store = connection.connect(from: store, state: state)
        return store.model
    }
}

public enum OutputHandler<Parent: ComponentModel, Child: ComponentModel> {
    case output((Child.Output) -> Parent.Output)
    case input((Child.Output) -> Parent.Input)
    case handle((ConnectionOutputContext<Parent, Child>) async -> Void)
    case ignore
}

public enum ActionHandler<Parent: ComponentModel, Child: ComponentModel> {
    case output((Child.Action) -> Parent.Output)
    case input((Child.Action) -> Parent.Input)
    case handle((ConnectionActionContext<Parent, Child>) async -> Void)
}


extension TestStep {

    public static func connection<Child: ComponentModel>(
        _ connection: KeyPath<Model, ModelConnection<Model, Child>>,
        state statePath: WritableKeyPath<Model.State, Child.State?>,
        file: StaticString = #filePath,
        line: UInt = #line,
        @TestStepBuilder<Child> _ steps: @escaping () -> [TestStep<Child>]
    ) -> Self {
        .init(
            title: "Connection",
            details: "\(Child.baseName)",
            file: file,
            line: line
        ) { context in
            guard let childState = context.model.state[keyPath: statePath] else {
                context.stepErrors.append(.init(error: "\(statePath.propertyName ?? Child.baseName) not connected", source: .init(file: file, line: line)))
                return
            }

            await self.connection(connection, state: .optionalKeyPath(statePath, fallback: childState), context: &context, steps)
        }
    }

    public static func connection<Child: ComponentModel>(
        _ connection: KeyPath<Model, ModelConnection<Model, Child>>,
        state: Child.State,
        file: StaticString = #filePath,
        line: UInt = #line,
        @TestStepBuilder<Child> _ steps: @escaping () -> [TestStep<Child>]
    ) -> Self {
        .init(
            title: "Connection",
            details: "\(Child.baseName)",
            file: file,
            line: line
        ) { context in
            await self.connection(connection, state: .value(state), context: &context, steps)
        }
    }

    public static func connection<Child: ComponentModel>(
        _ connection: KeyPath<Model, ModelConnection<Model, Child>>,
        state statePath: WritableKeyPath<Model.State, Child.State>,
        file: StaticString = #filePath,
        line: UInt = #line,
        @TestStepBuilder<Child> _ steps: @escaping () -> [TestStep<Child>]
    ) -> Self {
        .init(
            title: "Connection",
            details: "\(Child.baseName)",
            file: file,
            line: line
        ) { context in
            await self.connection(connection, state: .keyPath(statePath), context: &context, steps)
        }
    }

    public static func connection<Child: ComponentModel>(
        _ connection: KeyPath<Model, ModelConnection<Model, Child>>,
        state: Child.State,
        output: Child.Output,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Self {
        .init(
            title: "Connection Output",
            details: "\(Child.baseName).\(getEnumCase(output).name)",
            file: file,
            line: line
        ) { context in
            let model = context.model.connect(to: connection, state: .value(state))
            model.store.output(output, source: .capture(file: file, line: line))
            await Task.yield()
        }
    }

    public static func connection<Child: ComponentModel>(
        _ connection: KeyPath<Model, ModelConnection<Model, Child>>,
        state statePath: WritableKeyPath<Model.State, Child.State>,
        output: Child.Output,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Self {
        .init(
            title: "Connection Output",
            details: "\(Child.baseName).\(getEnumCase(output).name)",
            file: file,
            line: line
        ) { context in
            let model = context.model.connect(to: connection, state: .keyPath(statePath))
            model.store.output(output, source: .capture(file: file, line: line))
            await Task.yield()
        }
    }

    public static func connection<Child: ComponentModel>(
        _ connection: KeyPath<Model, ModelConnection<Model, Child>>,
        state statePath: WritableKeyPath<Model.State, Child.State?>,
        output: Child.Output,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Self {
        .init(
            title: "Connection Output",
            details: "\(Child.baseName).\(getEnumCase(output).name)",
            file: file,
            line: line
        ) { context in
            guard let childState = context.model.state[keyPath: statePath] else {
                context.stepErrors.append(.init(error: "\(statePath.propertyName ?? Child.baseName) not connected", source: .init(file: file, line: line)))
                return
            }
            let model = context.model.connect(to: connection, state: .optionalKeyPath(statePath, fallback: childState))
            model.store.output(output, source: .capture(file: file, line: line))
            await Task.yield()
        }
    }

    @MainActor
    static func connection<Child: ComponentModel>(
        _ connection: KeyPath<Model, ModelConnection<Model, Child>>,
        state: ScopedState<Model.State, Child.State>,
        context: inout TestContext<Model>,
        @TestStepBuilder<Child> _ steps: @escaping () -> [TestStep<Child>]
    ) async {

        if context.delay > 0 {
            try? await Task.sleep(nanoseconds: context.delayNanoseconds)
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 * 0.35)) // wait for typical presentation animation duration
        }

        let steps = steps()
        let model = context.model.connect(to: connection, state: state)
        var childContext = TestContext<Child>(model: model, delay: context.delay, assertions: context.assertions, state: model.state)
        for step in steps {
            let results = await step.runTest(context: &childContext)
            context.childStepResults.append(results)
        }
    }
}
