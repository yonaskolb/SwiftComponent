import SwiftUI
import SwiftPreview

public struct ComponentListView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    var components: [any Component.Type]
    let scale = 0.5
    let device = Device.mediumPhone
    var snapshots: [SnapshotViewModel]
    var environments: [String]

    public init(components: [any Component.Type]) {
        self.components = components
        self.snapshots = components.reduce([]) { $0 + Self.snapshots(component: $1)  }
        self.environments = Set(snapshots.reduce(Set<String>()) { $0.union([$1.environment]) }).sorted {
            if $0 == String(describing: EmptyEnvironment.self) {
                return true
            } else if $1 == String(describing: EmptyEnvironment.self) {
                return false
            } else {
                return $0 < $1
            }
        }
    }

    var componentModels: [ComponentViewModel] {
        var models: [ComponentViewModel] = []
        for component in components {
            models.append(ComponentViewModel(id: getID(component) + UUID().uuidString, component: component))
        }
        return models
    }

    static func snapshots<C: Component>(component: C.Type) -> [SnapshotViewModel] {
        let componentSnapshots = (C.snapshots.map(\.name) + C.testSnapshots.filter(\.featured).map(\.name))
        return componentSnapshots.map { snapshot in
            SnapshotViewModel(
                componentType: C.self,
                component: C.Model.baseName,
                snapshot: snapshot,
                environment: String(describing: C.Model.Environment.self)
            )
        }
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
                LazyVGrid(columns: [.init(.adaptive(minimum: device.width * scale + 20))], spacing: 0) {
                    ForEach(environments, id: \.self) { environment in
                        Section(header: environmentHeader(environment)) {
                            ForEach(snapshots.filter { $0.environment == environment}) { snapshot in
                                snapshotGridUnwrap(snapshot: snapshot, component: snapshot.componentType)
                                    .navigationViewStyle(.stack)
                            }
                            .padding()
                        }
                    }
                }
            }
            .background(colorScheme == .dark ? Color.darkBackground : .white)
        }
        .navigationViewStyle(.stack)
        .previewDevice(.largestDevice)
    }

    @ViewBuilder
    func environmentHeader(_ environment: String) -> some View {
        if environments.count > 1 {
            Text(environment)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 20))
                .padding(.horizontal, 26)
                .padding(.vertical, 12)
        } else {
            EmptyView()
        }
    }

    func componentGridView(_ component: any Component.Type) -> some View {
        componentGridUnwrap(component)
    }

    func componentGridUnwrap<ComponentType: Component>( _ component: ComponentType.Type) -> AnyView {
        AnyView(ComponentGridItem<ComponentType>(scale: scale, device: device))
    }

    func snapshotGridUnwrap<ComponentType: Component>(snapshot: SnapshotViewModel, component: ComponentType.Type) -> AnyView {
        AnyView(SnapshotGridItem<ComponentType>(snapshot: snapshot, scale: scale, device: device))
    }
}

struct SnapshotViewModel: Identifiable {
    let componentType: any Component.Type
    let component: String
    let snapshot: String
    let environment: String

    var id: String { "\(component).\(snapshot)"}
}

struct SnapshotGridItem<ComponentType: Component>: View {

    var snapshot: SnapshotViewModel
    let scale: Double
    let device: Device

    var body: some View {
        NavigationLink {
            ComponentPreview<ComponentType>()
        } label: {
            VStack(spacing: 2) {
                ComponentSnapshotView<ComponentType>(snapshotName: snapshot.snapshot)
                    .embedIn(device: device)
                    .previewColorScheme()
                    .previewReference()
                    .allowsHitTesting(false)
                    .scaleEffect(scale)
                    .frame(width: device.width*scale, height: device.height*scale)
                    .padding(.bottom, 12)
                Text(ComponentType.Model.baseName)
                    .bold()
                    .font(.system(size: 18))
                Text(snapshot.snapshot)
                    .font(.system(size: 18))
            }
            .interactiveBackground()
            .padding(20)
        }
        .buttonStyle(.plain)
    }
}

struct ComponentGridItem<ComponentType: Component>: View {

    @StateObject var model = ComponentType.previewModel()
    let scale: Double
    let device: Device

    var body: some View {
        NavigationLink {
            ComponentPreview<ComponentType>()
        } label: {
            VStack(spacing: 20) {
                ComponentType
                    .view(model: model)
                    .embedIn(device: device)
                    .previewColorScheme()
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
