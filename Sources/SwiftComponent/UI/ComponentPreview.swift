import SwiftUI
import SwiftPreview

struct ComponentPreview<ComponentType: Component>: View {

    @StateObject var model = ComponentType.previewModel().logEvents()
    @AppStorage("componentPreview.viewState") var viewState: ViewState = .dashboard

    enum ViewState: String, CaseIterable {
        case dashboard = "Component"
        case view = "View"
        case model = "Model"
        case code = "Code"
        case tests = "Tests"
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.top)
            Group {
                switch viewState {
                    case .dashboard:
                        ComponentDashboardView<ComponentType>(model: model)
                    case .view:
                        ComponentViewPreview(content: ComponentType.view(model: model))
                    case .tests:
                        ComponentTestsView<ComponentType>()
                    case .code:
                        ComponentEditorView<ComponentType>()
                    case .model:
                        ComponentDescriptionView<ComponentType>()
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker(selection: $viewState) {
                        ForEach(ViewState.allCases, id: \.rawValue) { viewState in
                            Text(viewState.rawValue).tag(viewState)
                        }
                    } label: {
                        Text("Mode")
                    }
//                    .scaleEffect(1.5)
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }
            #if os(iOS)
            .navigationViewStyle(.stack)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .previewDevice(.largestDevice)
        }
//        .edgesIgnoringSafeArea(.all)
    }

}

struct ComponentPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ComponentPreview<ExampleComponent>()
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
        .previewDevice(.largestDevice)
    }
}
