import Foundation

public protocol Component<State, Action> {

    associatedtype State = Void
    associatedtype Action = Never
    associatedtype Route = Never
    associatedtype Output = Never
    @MainActor func task(model: Model) async
    @MainActor func handleBinding(keyPath: PartialKeyPath<State>) async
    @MainActor func handle(action: Action, model: Model) async
    init()

    typealias Model = ComponentModel<Self>
}

extension Component {

    static var name: String {
        var name = String(describing: Self.self)
        if name.hasSuffix("Component") {
            name = String(name.dropLast(9))
        }
        return name
    }
}

//public extension Component where Action == Never {
//    static func handle(action: Action, model: Model) async {}
//}

public extension Component {
    func handleBinding(keyPath: PartialKeyPath<State>) async { }
    func task(model: Model) async { model.viewModel.handledTask = false }
}
