import Foundation

@MainActor
public protocol ComponentModel<State, Action> {

    associatedtype State = Void
    associatedtype Action = Never
    associatedtype Input = Never
    associatedtype Output = Never
    associatedtype Route = Never
    associatedtype Task: ModelTask = String
    associatedtype Environment = EmptyEnvironment
    @MainActor func appear(model: Model) async
    @MainActor func disappear(model: Model) async
    @MainActor func binding(keyPath: PartialKeyPath<State>, model: Model) async
    @MainActor func handle(action: Action, model: Model) async
    @MainActor func handle(input: Input, model: Model) async
    nonisolated func handle(event: Event)
    @discardableResult nonisolated func connect(route: Route, model: Model) -> Connection
    nonisolated init()

    typealias Model = ComponentModelStore<Self>
    typealias Scope<Model: ComponentModel> = ComponentConnection<Self, Model>
}

public protocol ModelTask {
    var taskName: String { get }
}
extension String: ModelTask {
    public var taskName: String { self }
}

extension RawRepresentable where RawValue == String {
    public var taskName: String { rawValue }
}

extension ComponentModel {

    nonisolated
    public static var baseName: String {
        var name = String(describing: Self.self)
        let suffixes: [String] = [
            "Component",
            "Model",
            "Feature",
        ]
        for suffix in suffixes {
            if name.hasSuffix(suffix) && name.count > suffix.count {
                name = String(name.dropLast(suffix.count))
            }
        }
        return name
    }
}

public extension ComponentModel where Action == Void {
    func handle(action: Void, model: Model) async {}
}

public extension ComponentModel where Input == Void {
    func handle(input: Void, model: Model) async {}
}

public extension ComponentModel where Route == Never {
    func connect(route: Route, model: Model) -> Connection { Connection() }
}

public extension ComponentModel {
    func binding(keyPath: PartialKeyPath<State>, model: Model) async { }
    func appear(model: Model) async { model.store.handledAppear = false }
    func disappear(model: Model) async { model.store.handledDisappear = false }
    @MainActor func handle(event: Event) { }
}

public struct ComponentConnection<From: ComponentModel, To: ComponentModel> {

    private let scope: (ViewModel<From>) -> ViewModel<To>
    public init(_ scope: @escaping (ViewModel<From>) -> ViewModel<To>) {
        self.scope = scope
    }

    func convert(_ from: ViewModel<From>) -> ViewModel<To> {
        scope(from)
    }
}
