import Foundation

public protocol ComponentModel<State, Input> {

    associatedtype State = Void
    associatedtype Input = Void
    associatedtype Output = Never
    associatedtype Route = Never
    associatedtype Task: ModelTask = String
    @MainActor func appear(model: Model) async
    @MainActor func binding(keyPath: PartialKeyPath<State>, model: Model) async
    @MainActor func handle(input: Input, model: Model) async
    init()

    typealias Model = ModelContext<Self>
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

public extension ComponentModel where Input == Void {
    func handle(input: Void, model: Model) async {}
}

public extension ComponentModel {
    func binding(keyPath: PartialKeyPath<State>, model: Model) async { }
    func appear(model: Model) async { model.viewModel.handledAppear = false }
}
