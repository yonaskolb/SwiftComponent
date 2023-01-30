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
    nonisolated init()

    typealias Store = ComponentModelStore<Self>
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

public extension ComponentModel {
    func binding(keyPath: PartialKeyPath<State>, store: Store) async { }
    func appear(store: Store) async { store.handledAppear = false }
}
