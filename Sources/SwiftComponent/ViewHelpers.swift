import Foundation
import SwiftUI

extension ViewModel {

    public func button<Label: View>(_ action: Model.Action, animation: Animation? = nil, file: StaticString = #file, line: UInt = #line, @ViewBuilder label: () -> Label) -> some View {
        ViewModelButton(model: self, action: action, animation: animation, file: file, line: line, label: label)
    }

    public func button(_ action: Model.Action, animation: Animation? = nil, _ text: LocalizedStringKey, file: StaticString = #file, line: UInt = #line) -> some View {
        ViewModelButton(model: self, action: action, animation: animation, file: file, line: line) { Text(text) }
    }
}

struct ViewModelButton<Model: ComponentModel, Label: View>: View {

    var model: ViewModel<Model>
    var action: Model.Action
    var animation: Animation?
    var file: StaticString
    var line: UInt
    var label: Label

    init(
        model: ViewModel<Model>,
        action: Model.Action,
        animation: Animation? = nil,
        file: StaticString = #file,
        line: UInt = #line,
        @ViewBuilder label: () -> Label) {
        self.model = model
        self.action = action
        self.animation = animation
        self.file = file
        self.line = line
        self.label = label()
    }

    var body: some View {
        Button {
            if let animation {
                withAnimation(animation) {
                    model.send(action, file: file, line: line)
                }
            } else {
                model.send(action, file: file, line: line)
            }
        } label: { label }
    }
}

extension View {

    func interactiveBackground() -> some View {
        contentShape(Rectangle())
    }

    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}
