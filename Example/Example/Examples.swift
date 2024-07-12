import SwiftUI
import SwiftComponent

struct ExamplesView: View {
    
    var body: some View {
        NavigationStack {
            Form {
                NavigationLink("Counter") {
                    CounterView(model: ViewModel(state: .init()))
                }
                NavigationLink("Counter Combine") {
                    CounterCombineView(model: ViewModel(state: .init()))
                }
                NavigationLink("Resource Loading") {
                    ResourceLoaderView(model: ViewModel(state: .init()))
                }
            }
        }
    }
}

#Preview {
    ExamplesView()
}
