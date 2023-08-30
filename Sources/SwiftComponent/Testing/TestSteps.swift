import Foundation
import SwiftUI

extension TestStep {

    public static func run(_ title: String, file: StaticString = #filePath, line: UInt = #line, _ run: @escaping () async -> Void) -> Self {
        .init(title: title, file: file, line: line) { _ in
            await run()
        }
    }
    
    public static func appear(first: Bool = true, await: Bool = true, file: StaticString = #filePath, line: UInt = #line) -> Self {
        .init(title: "Appear", file: file, line: line) { context in
            if `await` {
                await context.model.appearAsync(first: first, file: file, line: line)
            } else {
                context.model.appear(first: first, file: file, line: line)
            }
        }
    }

    public static func disappear(file: StaticString = #filePath, line: UInt = #line) -> Self {
        .init(title: "Disappear", file: file, line: line) { context in
            context.model.disappear(file: file, line: line)
        }
    }

    public static func action(_ action: Model.Action, file: StaticString = #filePath, line: UInt = #line) -> Self {
        .init(title: "Send Action", details: getEnumCase(action).name, file: file, line: line) { context in
            if context.delay > 0 {
                try? await Task.sleep(nanoseconds: context.delayNanoseconds)
            }
            await context.model.store.processAction(action, source: .capture(file: file, line: line))
        }
    }

    public static func input(_ input: Model.Input, file: StaticString = #filePath, line: UInt = #line) -> Self {
        .init(title: "Recieve Input", details: getEnumCase(input).name, file: file, line: line) { context in
            if context.delay > 0 {
                try? await Task.sleep(nanoseconds: context.delayNanoseconds)
            }
            await context.model.store.processInput(input, source: .capture(file: file, line: line))
        }
    }

    public static func binding<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, _ value: Value, animated: Bool = true, file: StaticString = #filePath, line: UInt = #line) -> Self {
        .init(title: "Set Binding", details: "\(keyPath.propertyName ?? "value") = \(value)", file: file, line: line) { context in
            if animated, let string = value as? String, string.count > 1, string != "", context.delay > 0 {
                let sleepTime = Double(context.delayNanoseconds)/(Double(string.count))
                var currentString = ""
                for character in string.dropLast(1) {
                    currentString.append(character)
                    context.model.store.state[keyPath: keyPath] = currentString as! Value
                    if sleepTime > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(sleepTime))
                    }
                }
            } else if context.delay > 0 {
                try? await Task.sleep(nanoseconds: context.delayNanoseconds)
            }
            context.state[keyPath: keyPath] = value
            await context.model.store.setBinding(keyPath, value)
        }
    }

    public static func binding<Value>(_ keyPath: WritableKeyPath<Model.State, Value?>, _ value: Value?, animated: Bool = true, file: StaticString = #filePath, line: UInt = #line) -> Self {
        .init(title: "Set Binding", details: "\(keyPath.propertyName ?? "value") = \(value != nil ? String(describing: value!) : "nil")", file: file, line: line) { context in
            if animated, let string = value as? String, string.count > 1, string != "", context.delay > 0 {
                let sleepTime = Double(context.delayNanoseconds)/(Double(string.count))
                var currentString = ""
                for character in string {
                    currentString.append(character)
                    context.model.store.state[keyPath: keyPath] = currentString as? Value
                    if sleepTime > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(sleepTime))
                    }
                }
            } else if context.delay > 0 {
                try? await Task.sleep(nanoseconds: context.delayNanoseconds)
            }
            context.state[keyPath: keyPath] = value
            await context.model.store.setBinding(keyPath, value)
        }
    }

    public static func dependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, _ dependency: T, file: StaticString = #filePath, line: UInt = #line) -> Self {
        .init(title: "Set Dependency", details: keyPath.propertyName ?? "\(String(describing: Swift.type(of: dependency)))", file: file, line: line) { context in
            context.model.store.dependencies.setDependency(keyPath, dependency)
        }
    }

    public static func route<Child: ComponentModel>(_ path: CasePath<Model.Route, ComponentRoute<Child>>, file: StaticString = #filePath, line: UInt = #line, @TestStepBuilder<Child> _ steps: @escaping () -> [TestStep<Child>]) -> Self {
        .init(title: "Route", details: "\(Child.baseName)", file: file, line: line) { context in
            guard let componentRoute = context.getRoute(path, source: .capture(file: file, line: line)) else { return }

            if context.delay > 0 {
                try? await Task.sleep(nanoseconds: context.delayNanoseconds)
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 * 0.35)) // wait for typical presentation animation duration
            }

            let steps = steps()
            let model = componentRoute.model
            var childContext = TestContext<Child>(model: model, delay: context.delay, assertions: context.assertions, state: model.state)
            for step in steps {
                let results = await step.runTest(context: &childContext)
                context.childStepResults.append(results)
            }
        }
    }

    public static func route<Child: ComponentModel>(_ path: CasePath<Model.Route, ComponentRoute<Child>>, output: Child.Output, file: StaticString = #filePath, line: UInt = #line) -> Self {
        .init(title: "Route Output", details: "\(Child.baseName).\(getEnumCase(output).name)", file: file, line: line) { context in

            guard let componentRoute = context.getRoute(path, source: .capture(file: file, line: line)) else { return }

            componentRoute.model.store.output(output, source: .capture(file: file, line: line))
            await Task.yield()
            if context.delay > 0 {
                try? await Task.sleep(nanoseconds: context.delayNanoseconds)
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 * 0.35)) // wait for typical presentation animation duration
            }
        }
    }

    public static func dismissRoute(file: StaticString = #filePath, line: UInt = #line) -> Self {
        .init(title: "Dimiss Route", file: file, line: line) { context in
            context.model.store.dismissRoute(source: .capture(file: file, line: line))
            await Task.yield()
            if context.delay > 0 {
                try? await Task.sleep(nanoseconds: context.delayNanoseconds)
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 * 0.35)) // wait for typical presentation animation duration
            }
        }
    }

    // TODO: support snapshots by making connenctions bi-directoional or removing type from Snapshot
    public static func scope<Child: ComponentModel>(_ connection: ComponentConnection<Model, Child>, file: StaticString = #filePath, line: UInt = #line, @TestStepBuilder<Child> steps: @escaping () -> [TestStep<Child>]) -> Self {
        .init(title: "Scope", details: Child.baseName, file: file, line: line) { context in
            //TODO: get the model that the view is using so it can playback in the preview
            let viewModel = connection.convert(context.model)
            let steps = steps()
            var childContext = TestContext<Child>(model: viewModel, delay: context.delay, assertions: context.assertions, state: viewModel.state)
            for step in steps {
                let results = await step.runTest(context: &childContext)
                context.childStepResults.append(results)
            }
        }
    }

    public static func branch(_ name: String, file: StaticString = #filePath, line: UInt = #line, @TestStepBuilder<Model> steps: @escaping () -> [TestStep<Model>]) -> Self {
        let steps = steps()
        let snapshots = steps.flatMap(\.snapshots)
        var step = TestStep<Model>(title: "Branch", details: name, file: file, line: line) { context in
            if context.delay > 0 {
                try? await Task.sleep(nanoseconds: context.delayNanoseconds)
            }

            let state = context.model.state
            let route = context.model.route
            let dependencyValues = context.model.dependencies.dependencyValues
            for step in steps {
                let results = await step.runTest(context: &context)
                context.childStepResults.append(results)
            }
            // reset state
            context.model.state = state
            context.state = state
            context.model.route = route
            context.model.dependencies.setValues(dependencyValues)

            // don't assert on this step
            context.runAssertions = false

            if context.delay > 0 {
                try? await Task.sleep(nanoseconds: context.delayNanoseconds)
            }
        }
        step.snapshots = snapshots
        return step
    }
}

extension TestContext {

    mutating func getRoute<Child: ComponentModel>(_ path: CasePath<Model.Route, ComponentRoute<Child>>, source: Source) -> ComponentRoute<Child>? {
        guard let route = model.store.route else {
            stepErrors = [TestError(error: "Couldn't route to \(Child.baseName)", source: source)]
            return nil
        }
        guard let componentRoute = path.extract(from: route) else {
            stepErrors = [TestError(error: "Couldn't route to \(Child.baseName)", source: source)]
            return nil
        }
        return componentRoute
    }
}
