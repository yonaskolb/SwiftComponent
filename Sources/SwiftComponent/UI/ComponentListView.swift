import SwiftUI
import SwiftPreview

public struct ComponentListView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    var components: [any Component.Type]
    let scale = 0.5
    let device = Device.mediumPhone
    var environments: [String]
    @State var testRuns: [String: ItemTestRun] = [:]
    @State var selectedSnapshotTag: String?
    @State var snapshotTags: Set<String> = []
    @AppStorage("componentList.viewType")
    var viewType: ViewType = .grid
    @AppStorage("componentList.environmentGroups")
    var environmentGroups: Bool = true

    var showEnvironmentGroups: Bool { environments.count > 1 && environmentGroups }

    enum ViewType: String, CaseIterable {
        case grid
        case list
        case snapshots

        var label: String {
            switch self {
            case .grid: return "Grid"
            case .list: return "List"
            case .snapshots: return "Snapshots"
            }
        }
    }

    struct ItemTestRun {
        let component: any Component.Type
        var environment: String
        let passed: Int
        let failed: Int
        let total: Int
        let snapshots: [SnapshotViewModel]
    }

    @MainActor
    struct ComponentViewModel: Identifiable {
        var id: String
        var component: any Component.Type
        var view: AnyView

        init<ComponentType: Component>(component: ComponentType.Type) {
            self.id = ComponentType.Model.baseName
            self.component = component
            self.view = AnyView(ComponentType.view(model: ComponentType.previewModel()))
        }
    }

    struct SnapshotViewModel: Identifiable {
        let componentType: any Component.Type
        var component: String { String(describing: componentType) }
        let snapshot: String
        let environment: String
        let view: AnyView
        let tags: Set<String>

        var id: String { "\(component).\(snapshot)"}
    }

    public init(components: [any Component.Type], selectedSnapshotTag: String? = nil) {
        self.components = components
        self._selectedSnapshotTag = .init(initialValue: selectedSnapshotTag)
        let environments = components.map { $0.environmentName }
        self.environments = Set(environments).sorted {
            if $0 == String(describing: EmptyEnvironment.self) {
                return true
            } else if $1 == String(describing: EmptyEnvironment.self) {
                return false
            } else {
                return $0 < $1
            }
        }
    }

    func snapshotModels(environment: String? = nil) -> [SnapshotViewModel] {
        testRuns
            .sorted { $0.key < $1.key }
            .map(\.value)
            .filter { environment == nil || $0.environment == environment }
            .reduce([]) { $0 + $1.snapshots }
            .filter {
                if let selectedSnapshotTag {
                    $0.tags.contains(selectedSnapshotTag)
                } else {
                    true
                }
            }
    }

    var componentModels: [ComponentViewModel] {
        var models: [ComponentViewModel] = []
        for component in components {
            models.append(ComponentViewModel(component: component))
        }
        return models
    }

    func componentModels(environment: String) -> [ComponentViewModel] {
        componentModels.filter { $0.component.environmentName == environment }
    }

    func runTests() {
        Task { @MainActor in
            for environment in environments {
                for component in components {
                    await test(component, environment: environment)
                }
            }
        }
    }

    func test<C: Component>(_ component: C.Type, environment: String) async {
        guard String(describing: C.environmentName) == environment else { return }
        var testRun = TestRun<C>()
        var snapshots: [ComponentSnapshot<C.Model>] = []
        for test in C.tests {
            let result = await C.run(test)
            for stepResult in result.steps {
                testRun.addStepResult(stepResult, test: test)
            }
            testRun.completeTest(test, result: result)
            snapshots.append(contentsOf: result.snapshots)
            snapshotTags.formUnion(result.snapshots.reduce([]) { $0 + $1.tags})
        }
        let itemTestRun = ItemTestRun(
            component: component,
            environment: C.environmentName,
            passed: testRun.passedStepCount,
            failed: testRun.failedStepCount,
            total: testRun.totalStepCount,
            snapshots: snapshots
                .map {
                    .init(
                        componentType: component,
                        snapshot: $0.name,
                        environment: C.environmentName,
                        view: AnyView(C.view(model: $0.viewModel())),
                        tags: $0.tags
                    )
                }
        )
        testRuns[C.Model.baseName] = itemTestRun
    }

    public var body: some View {
        NavigationView {
            VStack {
                header
                content
            }
#if os(iOS)
            .navigationViewStyle(.stack)
#endif
            .background(colorScheme == .dark ? Color.darkBackground : .white)
        }
#if os(iOS)
        .navigationViewStyle(.stack)
#endif
        .largePreview()
        .task { runTests() }
    }

    var header: some View {
        HStack(spacing: 20) {
            Picker("View", selection: $viewType.animation()) {
                ForEach(ViewType.allCases, id: \.rawValue) { viewType in
                    Text(viewType.label)
                        .tag(viewType)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .padding(.vertical, 2) // to give space for snapshot picker

            Spacer()
            if viewType == .snapshots, !snapshotTags.isEmpty {
                HStack(spacing: 0) {
                    Text("Tags")
                        .font(.callout)
                    Picker("Tags", selection: $selectedSnapshotTag.animation()) {
                        Text("All")
                            .tag(Optional<String>.none)
                        ForEach(snapshotTags.sorted(), id: \.self) { tag in
                            Text(tag)
                                .tag(tag as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
            if environments.count > 1 {
                HStack {
                    Text("Environment")
                        .font(.callout)
                    Toggle(isOn: $environmentGroups.animation()) {
                        Text("Environments")
                    }
                    .fixedSize()
                    .labelsHidden()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    var content: some View {
        ScrollView {
            switch viewType {
            case .grid:
                LazyVGrid(columns: [.init(.adaptive(minimum: device.width * scale + 20))], spacing: 0) {
                    if showEnvironmentGroups {
                        ForEach(environments, id: \.self) { environment in
                            Section(header: environmentHeader(environment)) {
                                gridItemViews(componentModels(environment: environment))
                            }
                        }
                    } else {
                        gridItemViews(componentModels)
                    }
                }
            case .list:
                LazyVStack {
                    if showEnvironmentGroups {
                        ForEach(environments, id: \.self) { environment in
                            Section(header: environmentHeader(environment)) {
                                listItemViews(componentModels(environment: environment))
                            }
                        }
                    } else {
                        listItemViews(componentModels)
                    }
                }
            case .snapshots:
                LazyVGrid(columns: [.init(.adaptive(minimum: device.width * scale + 20))], spacing: 0) {
                    if showEnvironmentGroups {
                        ForEach(environments, id: \.self) { environment in
                            Section(header: environmentHeader(environment)) {
                                snapsotItemViews(snapshotModels(environment: environment))
                            }
                        }
                    } else {
                        snapsotItemViews(snapshotModels())
                    }
                }
            }
        }
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
                .padding(.top, 20)
        } else {
            EmptyView()
        }
    }

    func gridItemViews(_ componentModels: [ComponentViewModel]) -> some View {
        ForEach(componentModels) { component in
            AnyView(gridItemView(component.component, model: component))
        }
    }

    func listItemViews(_ componentModels: [ComponentViewModel]) -> some View {
        ForEach(componentModels) { component in
            Divider()
            AnyView(listItemView(component.component))
        }
    }

    func snapsotItemViews(_ snapshotModels: [SnapshotViewModel]) -> some View {
        ForEach(snapshotModels) { snapshot in
            AnyView(snapshotView(snapshot: snapshot, component: snapshot.componentType))
        }
    }

    func gridItemView<ComponentType: Component>( _ component: ComponentType.Type, model: ComponentViewModel) -> some View {
        NavigationLink {
            ComponentPreview<ComponentType>()
        } label: {
            VStack(spacing: 4) {
                model.view
                    .embedIn(device: device)
                    .previewColorScheme()
                    .previewReference()
                    .allowsHitTesting(false)
                    .scaleEffect(scale)
                    .frame(width: device.width*scale, height: device.height*scale)
                    .padding(.bottom, 16)
                Text(ComponentType.Model.baseName)
                    .bold()
                    .font(.system(size: 20))
                testResults(component)
                Spacer()
            }
            .interactiveBackground()
            .padding(20)
        }
        .buttonStyle(.plain)
    }

    func snapshotView<ComponentType: Component>(snapshot: SnapshotViewModel, component: ComponentType.Type) -> some View {
        NavigationLink {
            ComponentPreview<ComponentType>()
        } label: {
            VStack(spacing: 4) {
                snapshot.view
                    .embedIn(device: device)
                    .previewColorScheme()
                    .previewReference()
                    .allowsHitTesting(false)
                    .scaleEffect(scale)
                    .frame(width: device.width*scale, height: device.height*scale)
                    .padding(.bottom, 16)
                Text(ComponentType.Model.baseName)
                    .bold()
                    .font(.system(size: 20))
                Text(snapshot.snapshot)
                    .foregroundColor(.secondary)
                    .font(.system(size: 20))
            }
            .interactiveBackground()
            .padding(20)
        }
        .buttonStyle(.plain)
    }

    func listItemView<ComponentType: Component>( _ component: ComponentType.Type) -> some View {
        NavigationLink {
            ComponentPreview<ComponentType>()
        } label: {
            HStack {
                Text(ComponentType.Model.baseName)
                    .font(.system(size: 18))
                Spacer()
                if ComponentType.environmentName != String(describing: EmptyEnvironment.self) {
                    Text(ComponentType.environmentName)
                        .foregroundColor(.secondary)
                }
                testResults(component)
                    .frame(minWidth: 100)
            }
            .padding()
            .padding(.horizontal)
            .interactiveBackground()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func testResults<ComponentType: Component>(_ component: ComponentType.Type) -> some View {
        if let testRun = testRuns[ComponentType.Model.baseName] {
            HStack(spacing: 4) {
                if testRun.failed > 0 {
                    Text(testRun.failed.description)
                        .bold()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                        .background {
                            Capsule().fill(Color.red)
                        }
                        .foregroundColor(.white)
                }
                if testRun.passed > 0 {
                    Text(testRun.passed.description)
                        .bold()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                        .background {
                            Capsule().fill(Color.green)
                        }
                        .foregroundColor(.white)
                }
            }
        }
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
