import Foundation
import SwiftComponent
import SwiftUI

@ComponentModel
struct CounterCombineModel {
    
    struct State: Equatable {
        var counter1 = CounterModel.State()
        var counter2 = CounterModel.State()
        var displayCount = true
    }
}

struct CounterCombineView: ComponentView {
    var model: ViewModel<CounterCombineModel>
    
    var view: some View {
        VStack(spacing: 20) {
            
            CounterView(model: model.scope(state: \.counter1))
            CounterView(model: model.scope(state: \.counter2))
            HStack {
                Toggle("Count", isOn: model.binding(\.displayCount))
                    .fixedSize()
                if model.displayCount {
                    Text("Total: \(model.counter1.count + model.counter2.count)")
                }
            }
        }
    }
}

struct CounterCombineComponent: Component, PreviewProvider {
    typealias Model = CounterCombineModel
    
    static func view(model: ViewModel<CounterCombineModel>) -> some View {
        CounterCombineView(model: model.logEvents().sendViewBodyEvents())
    }

    static var preview: PreviewModel = .init(state: .init())
}
