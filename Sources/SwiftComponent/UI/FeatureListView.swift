import SwiftUI
import SwiftPreview

public struct FeatureListView: View {
    var features: [any ComponentFeature.Type]

    public init(features: [any ComponentFeature.Type]) {
        self.features = features
    }

    var featureModels: [FeatureModel] {
        var models: [FeatureModel] = []
        for feature in features {
            models.append(FeatureModel(id: getID(feature) + UUID().uuidString, feature: feature))
        }
        return models
    }

    func getID<Feature: ComponentFeature>(_ feature: Feature.Type) -> String {
        Feature.Model.baseName
    }

    struct FeatureModel: Identifiable {
        var id: String
        var feature: any ComponentFeature.Type
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [.init(.adaptive(minimum: 200))]) {
                    ForEach(featureModels) { feature in
                        featureGridView(feature.feature)
                            .navigationViewStyle(.stack)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .previewDevice(.largestDevice)
    }

    func featureGridView(_ feature: any ComponentFeature.Type) -> some View {
        featureGridUnwrap(feature)
    }

    func featureGridUnwrap<Feature: ComponentFeature>( _ component: Feature.Type) -> AnyView {
        AnyView(FeatureGridItem<Feature>())
    }
}

struct FeatureGridItem<Feature: ComponentFeature>: View {

    @StateObject var viewModel = ViewModel<Feature.Model>.init(state: Feature.states[0].state)
    let scale = 0.5
    let device = Device.iPhone14
    var body: some View {
        NavigationLink {
            FeaturePreviewView<Feature>()
        } label: {
            VStack(spacing: 20) {
                Feature
                    .createView(model: viewModel)
                    .embedIn(device: device)
                    .previewReference()
                    .allowsHitTesting(false)
                    .scaleEffect(scale)
                    .frame(width: device.width*scale, height: device.height*scale)
                Text(Feature.Model.baseName)
                    .bold()
                    .font(.title2)
            }
            .interactiveBackground()
            .padding()
        }
        .buttonStyle(.plain)
    }
}

extension ComponentFeature {
    static var id: String { Model.baseName }
}
struct FeatureListView_Previews: PreviewProvider {
    static var previews: some View {
        FeatureListView(features: [ExamplePreview.self, ExamplePreview.self, ExamplePreview.self, ExamplePreview.self, ExamplePreview.self])
    }
}
