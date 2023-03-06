import Foundation

extension TestStep {

    public static func run(_ title: String, file: StaticString = #file, line: UInt = #line, _ run: @escaping () async -> Void) -> Self {
        .init(title: title, file: file, line: line) { _ in
            await run()
        }
    }
    
    public static func appear(first: Bool = true, await: Bool = true, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(title: "Appear", file: file, line: line) { context in
            if `await` {
                await context.model.appear(first: first)
            } else {
                Task { [context] in
                    await context.model.appear(first: first)
                }
            }
        }
    }

    public static func action(_ action: Model.Action, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(title: "Action", details: getEnumCase(action).name, file: file, line: line) { context in
            if context.delay > 0 {
                try? await Task.sleep(nanoseconds: context.delayNanoseconds)
            }
            await context.model.store.processAction(action, source: .capture(file: file, line: line))
        }
    }

    public static func input(_ input: Model.Input, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(title: "Input", details: getEnumCase(input).name, file: file, line: line) { context in
            await context.model.store.processInput(input, source: .capture(file: file, line: line))
        }
    }

    public static func binding<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, _ value: Value, animated: Bool = true, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(title: "Binding", details: "\(keyPath.propertyName ?? "value") = \(value)", file: file, line: line) { context in
            if animated, let string = value as? String, string.count > 1, string != "", context.delay > 0 {
                let sleepTime = Double(context.delayNanoseconds)/(Double(string.count))
                var currentString = ""
                for character in string {
                    currentString.append(character)
                    context.model.store.mutate(keyPath, value: currentString as! Value, source: .capture(file: file, line: line))
                    if sleepTime > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(sleepTime))
                    }
                }
            } else {
                if context.delay > 0 {
                    try? await Task.sleep(nanoseconds: context.delayNanoseconds)
                }
                context.model.store.mutate(keyPath, value: value, source: .capture(file: file, line: line))
            }
        }
    }

    public static func dependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, _ dependency: T, file: StaticString = #file, line: UInt = #line) -> Self {
        .init(title: "Dependency", details: "\(String(describing: Swift.type(of: dependency)))", file: file, line: line) { context in
            context.dependencies[keyPath: keyPath] = dependency
        }
    }

    public static func route<Child: ComponentModel>(_ path: CasePath<Model.Route, ComponentRoute<Child>>, file: StaticString = #file, line: UInt = #line, @TestStepBuilder<Child> _ steps: @escaping () -> [TestStep<Child>]) -> Self {
        Self.route(path, file: file, line: line) { _ in
            steps()
        }
    }

    public static func route<Child: ComponentModel>(_ path: CasePath<Model.Route, ComponentRoute<Child>>, file: StaticString = #file, line: UInt = #line, @TestStepBuilder<Child> _ steps: @escaping (TestStepContext<Child>.Type) -> [TestStep<Child>]) -> Self {
        .init(title: "Route", details: Child.baseName, file: file, line: line) { context in
            guard let route = context.model.store.route else { return }
            guard let componentRoute = path.extract(from: route) else { return }

            if context.delay > 0 {
                try? await Task.sleep(nanoseconds: context.delayNanoseconds)
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 * 0.35)) // wait for typical presentation animation duration
            }

            let steps = steps(TestStepContext<Child>.self)
            var childContext = TestContext<Child>(model: componentRoute.viewModel, dependencies: context.dependencies, delay: context.delay, assertions: context.assertions)
            for step in steps {
                let results = await step.runTest(context: &childContext)
                context.childStepResults.append(results)
            }
        }
    }

    public static func scope<Child: ComponentModel>(_ connection: ComponentConnection<Model, Child>, file: StaticString = #file, line: UInt = #line, @TestStepBuilder<Child> steps: @escaping () -> [TestStep<Child>]) -> Self {
        Self.scope(connection, file: file, line: line) { _ in
            steps()
        }
    }

    public static func scope<Child: ComponentModel>(_ connection: ComponentConnection<Model, Child>, file: StaticString = #file, line: UInt = #line, @TestStepBuilder<Child> steps: @escaping (TestStepContext<Child>.Type) -> [TestStep<Child>]) -> Self {
        .init(title: "Scope", details: Child.baseName, file: file, line: line) { context in
            let viewModel = connection.convert(context.model)
            let steps = steps(TestStepContext<Child>.self)
            var childContext = TestContext<Child>(model: viewModel, dependencies: context.dependencies, delay: context.delay, assertions: context.assertions)
            for step in steps {
                let results = await step.runTest(context: &childContext)
                context.childStepResults.append(results)
            }
        }
    }

    public static func fork(_ name: String, file: StaticString = #file, line: UInt = #line, @TestStepBuilder<Model> steps: @escaping () -> [TestStep<Model>]) -> Self {
        .init(title: name, file: file, line: line) { context in
            let steps = steps()
            let state = context.model.state
            for step in steps {
                let results = await step.runTest(context: &context)
                context.childStepResults.append(results)
            }
            // reset state
            context.model.state = state
        }
    }
}
