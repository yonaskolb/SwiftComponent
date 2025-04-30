import Foundation
import SwiftUI

public protocol Component: PreviewProvider {
    associatedtype Model: ComponentModel
    associatedtype ViewType: View

    typealias PreviewModel = ComponentSnapshot<Model>
    typealias Snapshots = [ComponentSnapshot<Model>]
    typealias Snapshot = ComponentSnapshot<Model>

    typealias Tests = [Test<Self>]

    typealias Route = ComponentModelRoute<Model.Route>
    typealias Routes = [Route]

    @SnapshotBuilder<Model> static var snapshots: Snapshots { get }
    @TestBuilder<Self> static var tests: Tests { get }
    @RouteBuilder static var routes: Routes { get }
    static var preview: PreviewModel { get }
    @ViewBuilder static func view(model: ViewModel<Model>) -> ViewType
    static var testAssertions: [TestAssertion] { get }
    // provided by tests or snapshots if they exist
    static var filePath: StaticString { get }
}

extension Component {

    public static var routes: Routes { [] }
    public static var testAssertions: [TestAssertion] { .standard }
    public static var snapshots: Snapshots { [] }
    public static var environmentName: String { String(describing: Model.Environment.self) }
    public static var name: String { String(describing: Self.self).replacingOccurrences(of: "Component", with: "") }
}

extension Component {

    public static var tests: Tests { [] }

    public static var embedInNav: Bool { false }
    public static var previews: some View {
        Group {
            componentPreview
                .previewDisplayName(Model.baseName)
            view(model: preview.viewModel())
                .previewDisplayName("Preview")
                .previewLayout(PreviewLayout.device)
            ForEach(snapshots, id: \.name) { snapshot in
                view(model: snapshot.viewModel())
                    .previewDisplayName(snapshot.name)
                    .previewReference()
                    .previewLayout(PreviewLayout.device)
            }
            ForEach(testSnapshots, id: \.name) { snapshot in
                ComponentSnapshotView<Self>(snapshotName: snapshot.name)
                    .previewDisplayName(snapshot.name)
                    .previewReference()
                    .previewLayout(PreviewLayout.device)
            }
        }
    }
    public static var componentPreview: some View {
        NavigationView {
            ComponentPreview<Self>()
        }
#if os(iOS)
        .navigationViewStyle(.stack)
#endif
        .largePreview()
    }

    public static func state(for test: Test<Self>) -> Model.State {
        switch test.state {
        case .state(let state):
            return state
        case .preview:
            return preview.state
        }
    }

    public static func previewModel() -> ViewModel<Model> {
        preview.viewModel().dependency(\.context, .preview)
    }
    
    /// Returns a view for a snapshot. Dependencies from the `preview` snapshot will be applied first
    public static func view(snapshot: ComponentSnapshot<Model>) -> ViewType {
        let viewModel = ViewModel<Model>(state: snapshot.state, environment: snapshot.environment, route: snapshot.route)
            .apply(preview.dependencies)
            .apply(snapshot.dependencies)
        return view(model: viewModel)
    }
}

extension Component {
    public static var filePath: StaticString { preview.source.file } // { tests.first?.source.file ?? allSnapshots.first?.source.file ?? .init() }

    static func readSource() -> String? {
        guard !filePath.description.isEmpty else { return nil }
        guard let data = FileManager.default.contents(atPath: filePath.description) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func writeSource(_ source: String) {
        guard !filePath.description.isEmpty else { return }
        let data = Data(source.utf8)
        FileManager.default.createFile(atPath: filePath.description, contents: data)
    }
}

