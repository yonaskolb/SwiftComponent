import SwiftUI
import SwiftPreview

struct ComponentPreviewView<ComponentType: Component>: View {

    @StateObject var model = ViewModel<ComponentType.Model>.init(state: ComponentType.states[0].state)
    @AppStorage("componentPreview.viewState") var viewState: ViewState = .dashboard

    enum ViewState: String, CaseIterable {
        case dashboard = "Dashboard"
        case view = "View"
        case description = "Description"
        case code = "Code"
        case tests = "Tests"
    }

    var body: some View {
        Group {
            switch viewState {
                case .dashboard:
                    ComponentDashboardView<ComponentType>(model: model)
                case .view:
                    ViewPreviewer(content: ComponentType.view(model: model))
                        .padding()
                        .previewReference()
                case .tests:
                    ComponentTestsView<ComponentType>()
                case .code:
                    ComponentEditorView<ComponentType>()
                case .description:
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
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
        .navigationViewStyle(.stack)
        .previewDevice(.largestDevice)
//        .edgesIgnoringSafeArea(.all)
    }

}

struct ComponentPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ComponentPreviewView<ExampleComponent>()
        }
        .navigationViewStyle(.stack)
        .previewDevice(.largestDevice)
    }
}
