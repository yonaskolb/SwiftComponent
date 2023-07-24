import Foundation
import SwiftUI

public protocol Component: PreviewProvider {
    associatedtype Model: ComponentModel
    associatedtype ViewType: View

    typealias PreviewModel = ComponentSnapshot<Model>
    typealias Snapshots = [ComponentSnapshot<Model>]
    typealias Snapshot = ComponentSnapshot<Model>

    typealias Tests = [Test<Model>]

    typealias Route = ComponentModelRoute<Model.Route>
    typealias Routes = [Route]

    @SnapshotBuilder static var snapshots: Snapshots { get }
    @TestBuilder<Model> static var tests: Tests { get }
    @RouteBuilder static var routes: Routes { get }
    static var preview: PreviewModel { get }
    @ViewBuilder static func view(model: ViewModel<Model>) -> ViewType
    static var testAssertions: Set<TestAssertion> { get }
    // provided by tests or snapshots if they exist
    static var filePath: StaticString { get }
}

extension Component {

    public static var routes: Routes { [] }
    public static var testAssertions: Set<TestAssertion> { .normal }
    public static var snapshots: Snapshots { [] }
    public static var environmentName: String { String(describing: Model.Environment.self) }
}

extension Component {

    public static var tests: Tests { [] }

    public static var embedInNav: Bool { false }
    public static var previews: some View {
        Group {
            componentPreview
                .previewDisplayName("\(Model.baseName) Component")
            view(model: preview.viewModel())
                .previewDisplayName("\(Model.baseName) preview")
                .previewLayout(PreviewLayout.device)
            ForEach(snapshots, id: \.name) { snapshot in
                view(model: snapshot.viewModel())
                    .previewDisplayName("\(Model.baseName): \(snapshot.name)")
                    .previewReference()
                    .previewLayout(PreviewLayout.device)
            }
            ForEach(testSnapshots, id: \.name) { snapshot in
                ComponentSnapshotView<Self>(snapshotName: snapshot.name)
                    .previewDisplayName("\(Model.baseName): \(snapshot.name)")
                    .previewReference()
                    .previewLayout(PreviewLayout.device)
            }
        }
    }
    public static var componentPreview: some View {
        NavigationView {
            ComponentPreview<Self>()
        }
        .navigationViewStyle(.stack)
        .previewDevice(.largestDevice)
    }

    public static func state(for test: Test<Model>) -> Model.State {
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

