import Foundation

public protocol Component<State, Action> {

    associatedtype State = Void
    associatedtype Action = Never
    associatedtype Output: Equatable = Never
    @MainActor func task(model: Model) async
    @MainActor func handleBinding(keyPath: PartialKeyPath<State>, model: Model) async
    @MainActor func handle(action: Action, model: Model) async
    init()

    typealias Model = ComponentModel<Self>
}

extension Component {

    public static var name: String {
        var name = String(describing: Self.self)
        if name.hasSuffix("Component") {
            name = String(name.dropLast(9))
        }
        if name.hasSuffix("Feature") {
            name = String(name.dropLast(7))
        }
        return name
    }
}

//public extension Component where Action == Never {
//    static func handle(action: Action, model: Model) async {}
//}

public extension Component {
    func handleBinding(keyPath: PartialKeyPath<State>, model: Model) async { }
    func task(model: Model) async { model.viewModel.handledTask = false }
}
