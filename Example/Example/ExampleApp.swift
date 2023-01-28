import SwiftUI

@main
struct ExampleApp: App {
    @State var state = ItemComponent.State(name: "Bob", data: .loading)

    var body: some Scene {
        WindowGroup {
            NavigationView {
                ItemView(model: .init(state: $state))
            }
//            ItemPreview.componentPreview
        }
    }
}
