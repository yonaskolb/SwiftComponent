import Foundation

public protocol ComponentModel<State, Input> {

    associatedtype State = Void
    associatedtype Input = Never
    associatedtype Output: Equatable = Never
    associatedtype Destination = Never
    @MainActor func viewTask(model: Model) async
    @MainActor func binding(keyPath: PartialKeyPath<State>, model: Model) async
    @MainActor func handle(input: Input, model: Model) async
    init()

    typealias Model = ComponentModelModel<Self>
}

extension ComponentModel {

    public static var baseName: String {
        var name = String(describing: Self.self)
        if name.hasSuffix("Component") {
            name = String(name.dropLast(9))
        }
        if name.hasSuffix("Model") {
            name = String(name.dropLast(5))
        }
        if name.hasSuffix("Feature") {
            name = String(name.dropLast(7))
        }
        return name
    }
}

//public extension ComponentModel where Input == Never {
//    static func handle(input: Input, model: Model) async {}
//}

public extension ComponentModel {
    func binding(keyPath: PartialKeyPath<State>, model: Model) async { }
    func viewTask(model: Model) async { model.viewModel.handledTask = false }
}
