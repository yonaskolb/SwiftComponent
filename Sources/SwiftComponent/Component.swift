import Foundation

public protocol Component<State, Action> {

    associatedtype State = Void
    associatedtype Action = Never
    associatedtype Route = Never
    associatedtype Output = Never
    func task(model: Model) async
    func handleBinding(keyPath: PartialKeyPath<State>) async
    func handle(action: Action, model: Model) async
    init()

    typealias Model = ComponentModel<Self>
}

//public extension Component where Action == Never {
//    static func handle(action: Action, model: Model) async {}
//}

public extension Component {
    func handleBinding(keyPath: PartialKeyPath<State>) async { }
    func task(model: Model) async { }
}
