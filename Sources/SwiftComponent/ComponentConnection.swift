import Foundation
import SwiftUI
import CasePaths

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
    
    public init(output: @escaping (To.Output) -> From.Input) where From.Environment == To.Environment {
        self.init(output: .input(output), environment: { $0.environment })
    }
    
    public init(output: @escaping (To.Output) -> From.Input, environment: @MainActor @escaping (From) -> To.Environment) {
        self.init(output: .input(output), environment: environment)
    }

    public init(_ output: @MainActor @escaping (ConnectionOutputContext<From, To>) async -> Void) where From.Environment == To.Environment {
        self.init(output: .handle(output), environment: { $0.environment })
    }

    @MainActor
    func connectedStore(from: ComponentStore<From>, state: ScopedState<From.State, To.State>, id: AnyHashable? = nil) -> ComponentStore<To> {
        let connectionID = ConnectionID(
            connectionID: self.id,
            storeID: from.id,
            childTypeName: String(describing: To.self),
            stateID: state.id,
            customID: id
        )
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
    let storeID: UUID
    let childTypeName: String
    let stateID: AnyHashable?
    let customID: AnyHashable?
}

//public protocol ConnectedContainer {
//
//    associatedtype Model: ComponentModel
//}
//
//extension ViewModel: ConnectedContainer {
//
//}
//
//extension ObservedObject.Wrapper where ObjectType: ConnectedContainer {
//
//    @MainActor
//    public subscript<Child: ComponentModel>(dynamicMember keyPath: KeyPath<ObjectType, EmbeddedComponentConnection<ObjectType.Model, Child>>) -> ViewModel<Child> {
//        let connection = self.store.model![keyPath: keyPath]
//        return connectedModel(connection)
//    }
//}

extension ViewModel {

    @dynamicMemberLookup
    public struct Connections {

        let model: ViewModel<Model>

        @MainActor
        public subscript<Child: ComponentModel>(dynamicMember keyPath: KeyPath<Model, EmbeddedComponentConnection<Model, Child>>) -> ViewModel<Child> {
            let connection = model.store.model![keyPath: keyPath]
            return model.connectedModel(connection)
        }
    }

    public var connections: Connections { Connections(model: self) }
}

extension ComponentView {

    public var connections: ViewModel<Model>.Connections { model.connections }
}

extension ViewModel { 

    @MainActor
    func connect<Child: ComponentModel>(to connection: ModelConnection<Model, Child>, state: ScopedState<Model.State, Child.State>, id: AnyHashable? = nil) -> ViewModel<Child> {
        let store = connection.connectedStore(from: store, state: state, id: id)
        return store.viewModel()
        // cache view models?
//        if let model = children[store.id] as? ViewModel<Child> {
//            return model
//        } else {
//            let model = store.viewModel()
//            children[store.id] = model
//            return model
//        }
    }
}

extension ViewModel {

    @MainActor
    public func connectedModel<Child: ComponentModel>(_ connection: ModelConnection<Model, Child>, state: Child.State, id: AnyHashable) -> ViewModel<Child> {
        connect(to: connection, state: .value(state), id: id)
    }
    
    @MainActor
    public func connectedModel<Child: ComponentModel>(_ connection: ModelConnection<Model, Child>, state: Child.State) -> ViewModel<Child> where Child.State: Hashable {
        connect(to: connection, state: .value(state), id: state)
    }

    @MainActor
    public func connectedModel<Child: ComponentModel>(_ connection: ModelConnection<Model, Child>, state: Binding<Child.State>) -> ViewModel<Child> {
        connect(to: connection, state: .binding(state))
    }

    @MainActor
    public func connectedModel<Child: ComponentModel>(_ connection: EmbeddedComponentConnection<Model, Child>) -> ViewModel<Child> {
        connect(to: connection.connection, state: .keyPath(connection.state))
    }

    @MainActor
    public func connectedModel<Child: ComponentModel>(_ connection: PresentedComponentConnection<Model, Child>, state: Child.State) -> ViewModel<Child> {
        connect(to: connection.connection, state: .optionalKeyPath(connection.state, fallback: state))
    }
}

// presentation binding
extension ViewModel {

    @MainActor
    public func presentedModel<Child: ComponentModel>(_ connection: PresentedComponentConnection<Model, Child>) -> Binding<ViewModel<Child>?> {
        presentedModel(connection.connection, state: connection.state)
    }
    
    @MainActor
    public func presentedModel<Child: ComponentModel, Case: CasePathable>(_ connection: PresentedCaseComponentConnection<Model, Child, Case>) -> Binding<ViewModel<Child>?> {
        presentedModel(connection.connection, state: connection.state, case: connection.casePath)
    }
    
    @MainActor
    public func presentedModel<Child: ComponentModel>(_ connection: ModelConnection<Model, Child>, state: WritableKeyPath<Model.State, Child.State?>) -> Binding<ViewModel<Child>?> {
        Binding(
            get: {
                if let presentedState = self.store.state[keyPath: state] {
                    return self.connect(to: connection, state: .optionalKeyPath(state, fallback: presentedState))
                } else {
                    return nil
                }
            },
            set: { model in
                if model == nil, self.state[keyPath: state] != nil {
                    self.state[keyPath: state] = nil
                }
            }
        )
    }
    
    @MainActor
    public func presentedModel<Child: ComponentModel, StateEnum: CasePathable>(_ connection: ModelConnection<Model, Child>, state statePath: WritableKeyPath<Model.State, StateEnum?>, case casePath: CaseKeyPath<StateEnum, Child.State>) -> Binding<ViewModel<Child>?> {
        Binding<ViewModel<Child>?>(
            get: {
                if let enumCase = self.store.state[keyPath: statePath],
                   let presentedState = enumCase[case: casePath] {
                    return self.connect(to: connection, state: self.store.caseScopedState(state: statePath, case: casePath, value: presentedState))
                } else {
                    return nil
                }
            },
            set: { model in
                if model == nil, self.state[keyPath: statePath] != nil {
                    self.state[keyPath: statePath] = nil
                }
            }
        )
    }
}

extension ComponentModel {

    public func connection<To: ComponentModel>(_ connection: ModelConnection<Self, To>, state: ScopedState<State, To.State>) -> To {
        let store = connection.connectedStore(from: store, state: state)
        return store.model
    }

    public func connection<To: ComponentModel>(_ connection: EmbeddedComponentConnection<Self, To>) -> To {
        self.connection(connection.connection, state: .keyPath(connection.state))
    }

    public func connection<To: ComponentModel>(_ connection: PresentedComponentConnection<Self, To>) -> To? {
        guard let state = self.store.state[keyPath: connection.state] else { return nil }
        return self.connection(connection.connection, state: .optionalKeyPath(connection.state, fallback: state))
    }

    public func connection<To: ComponentModel>(_ connection: ModelConnection<Self, To>, state: WritableKeyPath<Self.State, To.State?>) -> To? {
        guard let childState = store.state[keyPath: state] else { return nil }
        return self.connection(connection, state: .optionalKeyPath(state, fallback: childState))
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


// ModelConnection
extension TestStep {

    @MainActor
    public static func connection<Child: ComponentModel>(
        _ connection: ModelConnection<Model, Child>,
        state: Child.State,
        file: StaticString = #filePath,
        line: UInt = #line,
        @TestStepBuilder<Child> steps: @escaping () -> [TestStep<Child>]
    ) -> Self {
        Self.connection(connection, state: .value(state), file: file, line: line, steps: steps)
    }

    @MainActor
    public static func connection<Child: ComponentModel>(
        _ connection: ModelConnection<Model, Child>,
        state: ScopedState<Model.State, Child.State>,
        file: StaticString = #filePath,
        line: UInt = #line,
        @TestStepBuilder<Child> steps: @escaping () -> [TestStep<Child>]
    ) -> Self {
        .init(
            title: "Connection",
            details: "\(Child.baseName)",
            file: file,
            line: line
        ) { context in
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

    @MainActor
    public static func connection<Child: ComponentModel>(
        _ connection: ModelConnection<Model, Child>,
        state: ScopedState<Model.State, Child.State>,
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
            let model = context.model.connect(to: connection, state: state)
            model.store.output(output, source: .capture(file: file, line: line))
            await Task.yield()
        }
    }

    @MainActor
    public static func connection<Child: ComponentModel>(
        _ connection: ModelConnection<Model, Child>,
        state keyPath: WritableKeyPath<Model.State, Child.State?>,
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
            guard let state = context.model.state[keyPath: keyPath] else {
                context.stepErrors.append(.init(error: "\(keyPath.propertyName ?? Child.baseName) not connected", source: .init(file: file, line: line)))
                return
            }
            let model = context.model.connect(to: connection, state: .optionalKeyPath(keyPath, fallback: state))
            model.store.output(output, source: .capture(file: file, line: line))
            await Task.yield()
        }
    }
    
    @MainActor
    public static func connection<Child: ComponentModel, Case: CasePathable>(
        _ connection: ModelConnection<Model, Child>,
        state keyPath: WritableKeyPath<Model.State, Case?>,
        case casePath: CaseKeyPath<Case, Child.State>,
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
            guard let `case` = context.model.state[keyPath: keyPath], let state = `case`[case: casePath] else {
                context.stepErrors.append(.init(error: "\(keyPath.propertyName ?? Child.baseName) not connected", source: .init(file: file, line: line)))
                return
            }
            let model = context.model.connect(to: connection, state: context.model.store.caseScopedState(state: keyPath, case: casePath, value: state))
            model.store.output(output, source: .capture(file: file, line: line))
            await Task.yield()
        }
    }
    
    @MainActor
    public static func connection<Child: ComponentModel, Case: CasePathable>(
        _ connection: ModelConnection<Model, Child>,
        state keyPath: WritableKeyPath<Model.State, Case?>,
        case casePath: CaseKeyPath<Case, Child.State>,
        file: StaticString = #filePath,
        line: UInt = #line,
        @TestStepBuilder<Child> steps: @escaping () -> [TestStep<Child>]
    ) -> Self {
        .init(
            title: "Connection",
            details: "\(Child.baseName)",
            file: file,
            line: line
        ) { context in
            guard let `case` = context.model.state[keyPath: keyPath], let state = `case`[case: casePath] else {
                context.stepErrors.append(.init(error: "\(keyPath.propertyName ?? Child.baseName) not connected", source: .init(file: file, line: line)))
                return
            }

            if context.delay > 0 {
                try? await Task.sleep(nanoseconds: context.delayNanoseconds)
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 * 0.35)) // wait for typical presentation animation duration
            }

            let steps = steps()
            let model = context.model.connect(to: connection, state: context.model.store.caseScopedState(state: keyPath, case: casePath, value: state))
            var childContext = TestContext<Child>(model: model, delay: context.delay, assertions: context.assertions, state: model.state)
            for step in steps {
                let results = await step.runTest(context: &childContext)
                context.childStepResults.append(results)
            }
        }
    }

    @MainActor
    public static func connection<Child: ComponentModel>(
        _ connection: ModelConnection<Model, Child>,
        state keyPath: WritableKeyPath<Model.State, Child.State?>,
        file: StaticString = #filePath,
        line: UInt = #line,
        @TestStepBuilder<Child> steps: @escaping () -> [TestStep<Child>]
    ) -> Self {
        .init(
            title: "Connection",
            details: "\(Child.baseName)",
            file: file,
            line: line
        ) { context in
            guard let state = context.model.state[keyPath: keyPath] else {
                context.stepErrors.append(.init(error: "\(keyPath.propertyName ?? Child.baseName) not connected", source: .init(file: file, line: line)))
                return
            }

            if context.delay > 0 {
                try? await Task.sleep(nanoseconds: context.delayNanoseconds)
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 * 0.35)) // wait for typical presentation animation duration
            }

            let steps = steps()
            let model = context.model.connect(to: connection, state: .optionalKeyPath(keyPath, fallback: state))
            var childContext = TestContext<Child>(model: model, delay: context.delay, assertions: context.assertions, state: model.state)
            for step in steps {
                let results = await step.runTest(context: &childContext)
                context.childStepResults.append(results)
            }
        }
    }
}

// ModelConnection.connected
extension TestStep {
    
    @MainActor
    public static func connection<Child: ComponentModel>(
        _ connection: EmbeddedComponentConnection<Model, Child>,
        output: Child.Output,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Self {
        self.connection(connection.connection, state: .keyPath(connection.state), output: output, file: file, line: line)
    }

    @MainActor
    public static func connection<Child: ComponentModel>(
        _ connection: EmbeddedComponentConnection<Model, Child>,
        file: StaticString = #filePath,
        line: UInt = #line,
        @TestStepBuilder<Child> steps: @escaping () -> [TestStep<Child>]
    ) -> Self {
        self.connection(connection.connection, state: .keyPath(connection.state), file: file, line: line, steps: steps)
    }

    @MainActor
    public static func connection<Child: ComponentModel>(
        _ connection: PresentedComponentConnection<Model, Child>,
        file: StaticString = #filePath,
        line: UInt = #line,
        @TestStepBuilder<Child> steps: @escaping () -> [TestStep<Child>]
    ) -> Self {
        self.connection(connection.connection, state: connection.state, file: file, line: line, steps: steps)
    }

    @MainActor
    public static func connection<Child: ComponentModel>(
        _ connection: PresentedComponentConnection<Model, Child>,
        output: Child.Output,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Self {
        self.connection(connection.connection, state: connection.state, output: output, file: file, line: line)
    }
    
    @MainActor
    public static func connection<Child: ComponentModel, Case: CasePathable>(
        _ connection: PresentedCaseComponentConnection<Model, Child, Case>,
        file: StaticString = #filePath,
        line: UInt = #line,
        @TestStepBuilder<Child> steps: @escaping () -> [TestStep<Child>]
    ) -> Self {
        self.connection(connection.connection, state: connection.state, case: connection.casePath, file: file, line: line, steps: steps)
    }
    
    @MainActor
    public static func connection<Child: ComponentModel, Case: CasePathable>(
        _ connection: PresentedCaseComponentConnection<Model, Child, Case>,
        output: Child.Output,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Self {
        self.connection(connection.connection, state: connection.state, case: connection.casePath, output: output, file: file, line: line)
    }
}

public struct EmbeddedComponentConnection<From: ComponentModel, To: ComponentModel> {

    public let connection: ModelConnection<From, To>
    public let state: WritableKeyPath<From.State, To.State>
}

public struct PresentedComponentConnection<From: ComponentModel, To: ComponentModel> {

    public let connection: ModelConnection<From, To>
    public let state: WritableKeyPath<From.State, To.State?>
}

public struct PresentedCaseComponentConnection<From: ComponentModel, To: ComponentModel, Case: CasePathable> {

    public let connection: ModelConnection<From, To>
    public let state: WritableKeyPath<From.State, Case?>
    public let casePath: CaseKeyPath<Case, To.State>
}

extension ModelConnection {

    public func connect(state: WritableKeyPath<From.State, To.State>) -> EmbeddedComponentConnection<From, To> {
        EmbeddedComponentConnection(connection: self, state: state)
    }

    public func connect(state: WritableKeyPath<From.State, To.State?>) -> PresentedComponentConnection<From, To> {
        PresentedComponentConnection(connection: self, state: state)
    }
    
    public func connect<Case: CasePathable>(state: WritableKeyPath<From.State, Case?>, case casePath: CaseKeyPath<Case, To.State>) -> PresentedCaseComponentConnection<From, To, Case> {
        PresentedCaseComponentConnection(connection: self, state: state, casePath: casePath)
    }
}
