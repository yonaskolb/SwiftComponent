import SwiftUI
import SwiftPreview

public struct ComponentListView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    var components: [any Component.Type]

    public init(components: [any Component.Type]) {
        self.components = components
    }

    var componentModels: [ComponentViewModel] {
        var models: [ComponentViewModel] = []
        for component in components {
            models.append(ComponentViewModel(id: getID(component) + UUID().uuidString, component: component))
        }
        return models
    }

    func getID<ComponentType: Component>(_ component: ComponentType.Type) -> String {
        ComponentType.Model.baseName
    }

    struct ComponentViewModel: Identifiable {
        var id: String
        var component: any Component.Type
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [.init(.adaptive(minimum: 200))]) {
                    ForEach(componentModels) { component in
                        componentGridView(component.component)
                            .navigationViewStyle(.stack)
                    }
                }
                .padding(.top)
            }
            .background(colorScheme == .dark ? Color(white: 0.1) : .white)
        }
        .navigationViewStyle(.stack)
        .previewDevice(.largestDevice)
    }

    func componentGridView(_ component: any Component.Type) -> some View {
        componentGridUnwrap(component)
    }

    func componentGridUnwrap<ComponentType: Component>( _ component: ComponentType.Type) -> AnyView {
        AnyView(ComponentGridItem<ComponentType>())
    }
}

struct ComponentGridItem<ComponentType: Component>: View {

    @StateObject var model = ComponentType.previewModel()
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    let scale = 0.5
    let device = Device.iPhone14
    var body: some View {
        NavigationLink {
            ComponentPreview<ComponentType>()
        } label: {
            VStack(spacing: 20) {
                ComponentType
                    .view(model: model)
                    .embedIn(device: device)
                    .colorScheme(PreviewColorScheme.current.colorScheme ?? colorScheme)
//                    .previewReference()
                    .allowsHitTesting(false)
                    .scaleEffect(scale)
                    .frame(width: device.width*scale, height: device.height*scale)
                Text(ComponentType.Model.baseName)
                    .bold()
                    .font(.title2)
            }
            .interactiveBackground()
            .padding(20)
        }
        .buttonStyle(.plain)
    }
}

extension Component {
    static var id: String { Model.baseName }
}
struct ComponentTypeListView_Previews: PreviewProvider {
    static var previews: some View {
        ComponentListView(components: [ExampleComponent.self, ExampleComponent.self, ExampleComponent.self, ExampleComponent.self, ExampleComponent.self])
    }
}
