import SwiftUI
import SwiftComponent

@main
struct ExampleApp: App {
    @State var state = ItemModel.State(name: "Bob", data: .loading)

    var body: some Scene {
        WindowGroup {
            NavigationView {
                ItemView(model: .init(state: $state))
            }
//            ItemPreview.componentPreview
        }
    }
}

struct MyPreviewProvider_Previews: PreviewProvider {
    static var previews: some View {
        ComponentListView(components: components)
    }
}
