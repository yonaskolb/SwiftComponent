import Foundation
import SwiftUI

extension ViewModel {

    public func button<Label: View>(_ input: Model.Input, animation: Animation? = nil, file: StaticString = #file, line: UInt = #line, @ViewBuilder label: () -> Label) -> some View {
        ViewModelButton(model: self, input: input, animation: animation, file: file, line: line, label: label)
    }

    public func button(_ input: Model.Input, animation: Animation? = nil, _ text: LocalizedStringKey, file: StaticString = #file, line: UInt = #line) -> some View {
        ViewModelButton(model: self, input: input, animation: animation, file: file, line: line) { Text(text) }
    }
}

struct ViewModelButton<Model: ComponentModel, Label: View>: View {

    var model: ViewModel<Model>
    var input: Model.Input
    var animation: Animation?
    var file: StaticString
    var line: UInt
    var label: Label

    init(
        model: ViewModel<Model>,
        input: Model.Input,
        animation: Animation? = nil,
        file: StaticString = #file,
        line: UInt = #line,
        @ViewBuilder label: () -> Label) {
        self.model = model
        self.input = input
        self.animation = animation
        self.file = file
        self.line = line
        self.label = label()
    }

    var body: some View {
        Button {
            if let animation {
                withAnimation(animation) {
                    model.send(input, file: file, line: line)
                }
            } else {
                model.send(input, file: file, line: line)
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
