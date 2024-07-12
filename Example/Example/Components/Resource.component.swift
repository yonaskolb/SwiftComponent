import Foundation
import SwiftComponent
import SwiftUI

@ComponentModel
struct ResourceLoaderModel {

    struct State {
        @Resource var itemAutoload: Item?
        @Resource var itemLoad: Item?
    }
    
    struct Item: Equatable {
        var name: String
        var count: Int
    }

    enum Action {
        case load
    }
    
    func appear() async {
        await loadResource(\.$itemAutoload) {
            return Item(name: "loaded on appear", count: 1)
        }
    }

    func handle(action: Action) async {
        switch action {
        case .load:
            await loadResource(\.$itemLoad) {
                try? await dependencies.continuousClock.sleep(for: .seconds(1))
                return Item(name: "loaded from an action", count: .random(in: 0..<100))
            }
        }
    }
}

struct ResourceLoaderView: ComponentView {

    var model: ViewModel<ResourceLoaderModel>

    var view: some View {
        let _ = Self._printChanges()
        VStack {
            ResourceView(model.$itemAutoload) { item in
                Text(item.name)
            } error: { error in
                Text("\(error)").foregroundStyle(.red)
            }
            
            button(.load, "Load")
            ResourceView(model.$itemLoad) { item in
                Text("\(item.name)\(item.count)")
            } error: { error in
                Text("\(error)").foregroundStyle(.red)
            }
            .fixedSize()
            Spacer()
        }
        .padding()
    }
}

struct ResourceLoaderComponent: Component, PreviewProvider {
    
    typealias Model = ResourceLoaderModel

    static func view(model: ViewModel<Model>) -> some View {
        ResourceLoaderView(model: model.logEvents().sendViewBodyEvents())
    }

    static var preview = PreviewModel(state: .init())
}
