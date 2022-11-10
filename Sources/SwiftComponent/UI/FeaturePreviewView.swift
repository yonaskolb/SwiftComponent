//
//  SwiftUIView.swift
//  
//
//  Created by Yonas Kolb on 22/10/2022.
//

import SwiftUI
import SwiftPreview

struct FeaturePreviewView<Feature: ComponentFeature>: View {

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
        Group {
            switch viewState {
                case .feature:
                    FeatureDashboardView<Feature>()
                case .view:
                    ViewPreviewer(content: Feature.createView(model: viewModel))
                        .padding()
                case .tests:
                    FeaureTestsView<Feature>()
                case .code:
                    FeatureEditorView<Feature>()
                case .model:
                    FeatureDescriptionView<Feature>()
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
        .edgesIgnoringSafeArea(.all)
    }

}

struct ComponentPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FeaturePreviewView<ExamplePreview>()
        }
    }
}
