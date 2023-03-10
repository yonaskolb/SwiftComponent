import Foundation

@MainActor
public protocol ComponentModel<State, Action> {

    associatedtype State = Void
    associatedtype Action = Never
    associatedtype Input = Never
    associatedtype Output = Never
    associatedtype Route = Never
    associatedtype Task: ModelTask = String
    @MainActor func appear(store: Store) async
    @MainActor func binding(keyPath: PartialKeyPath<State>, store: Store) async
    @MainActor func handle(action: Action, store: Store) async
    @MainActor func handle(input: Input, store: Store) async
    nonisolated func handle(event: Event)
    @discardableResult nonisolated func connect(route: Route, store: Store) -> Connection
    nonisolated init()

    typealias Store = ComponentModelStore<Self>
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
    func handle(action: Void, store: Store) async {}
}

public extension ComponentModel where Input == Void {
    func handle(input: Void, store: Store) async {}
}

public extension ComponentModel where Route == Never {
    func connect(route: Route, store: Store) -> Connection { Connection() }
}

public extension ComponentModel {
    func binding(keyPath: PartialKeyPath<State>, store: Store) async { }
    func appear(store: Store) async { store.handledAppear = false }
    @MainActor func handle(event: Event) { }
}

public struct ComponentConnection<From: ComponentModel, To: ComponentModel> {

    private let scope: (ViewModel<From>) -> ViewModel<To>
    public init(_ scope: @escaping (ViewModel<From>) -> ViewModel<To>) {
        self.scope = scope
    }

    func convert(_ from: ViewModel<From>) -> ViewModel<To> {
        from.store.graph.getScopedModel(model: from, child: To.self) ?? scope(from)
    }
}
