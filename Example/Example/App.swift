import SwiftUI
import SwiftComponent

@main
struct ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ExamplesView()
        }
    }
}

struct MyPreviewProvider_Previews: PreviewProvider {
    static var previews: some View {
        ComponentListView(components: components)
    }
}
