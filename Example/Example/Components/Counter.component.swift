import Foundation
import SwiftComponent
import SwiftUI

@ComponentModel
struct CounterModel {

    struct State: Equatable {
        var count = 0
        var displayingCount = true
    }

    enum Action {
        case updateCount(Int)
        case reset
    }

    func handle(action: Action) async {
        switch action {
        case .updateCount(let amount):
            state.count += amount
        case .reset:
            mutate(\.self, .init())
        }
    }
}

struct CounterView: ComponentView {

    var model: ViewModel<CounterModel>

    var view: some View {
        VStack {
            HStack {
                button(.updateCount(-1)) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderedProminent)
                button(.updateCount(1)) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderedProminent)
            }
            HStack {
                Toggle("Count", isOn: model.binding(\.displayingCount))
                    .fixedSize()
                if model.displayingCount {
                    Text(model.count.formatted())
                        .frame(minWidth: 20, alignment: .leading)
                }
            }
            button(.reset, "Reset")
        }
    }
}

struct CounterComponent: Component, PreviewProvider {
    
    typealias Model = CounterModel

    static func view(model: ViewModel<CounterModel>) -> some View {
        CounterView(model: model.logEvents().sendViewBodyEvents())
    }

    static var preview = PreviewModel(state: .init())
}
