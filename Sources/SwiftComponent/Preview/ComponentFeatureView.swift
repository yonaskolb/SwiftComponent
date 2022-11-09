//
//  SwiftUIView.swift
//  
//
//  Created by Yonas Kolb on 22/10/2022.
//

import SwiftUI
import SwiftPreview

struct ComponentFeatureView<Feature: ComponentFeature>: View {

    @StateObject var viewModel = ViewModel<Feature.Model>.init(state: Feature.states[0].state)
    @AppStorage("componentPreview.viewState") var viewState: ViewState = .feature

    enum ViewState: String, CaseIterable {
        case feature = "Feature"
        case view = "View"
        case model = "Model"
        case code = "Code"
        case tests = "Tests"
    }

    var body: some View {
        NavigationView {
            Group {
                switch viewState {
                    case .feature:
                        ComponentFeatureDashboard<Feature>()
                    case .view:
                        ViewPreviewer(content: Feature.createView(model: viewModel))
                            .padding()
                    case .tests:
                        ComponentFeatureTestsView<Feature>()
                    case .code:
                        ComponentEditorView<Feature>()
                    case .model:
                        ComponentFeatureGraphView<Feature>()
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
        }
        .navigationViewStyle(.stack)
        .previewDevice(.largestDevice)
        .edgesIgnoringSafeArea(.all)
    }

}

struct ComponentPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        ComponentFeatureView<ExamplePreview>()
    }
}
