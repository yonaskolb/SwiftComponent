import Foundation

//typealias SimpleModel<State, Action, Environment> = ViewModel<SimpleComponentModel<State, Action, Environment>>
//struct SimpleComponentModel<State, Output, Environment>: ComponentModel {
//
//    typealias State = State
//    typealias Action = Output
//    typealias Output = Output
//    typealias Environment = Environment
//
//    static func handle(action: Action, model: Model) async {
//        model.output(action)
//    }
//}

public protocol ActionOutput: ComponentModel where Action == Output {}
public extension ActionOutput {

    func handle(action: Action, model: Model) async {
        await model.output(action)
    }
}
