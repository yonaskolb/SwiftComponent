//
//  SwiftUIView.swift
//  
//
//  Created by Yonas Kolb on 26/6/2023.
//

import SwiftUI

struct ComponentSnapshotView<ComponentType: Component>: View {
    let snapshotName: String
    @State var snapshot: ComponentSnapshot<ComponentType.Model>?

    @MainActor
    func generateSnapshot() async {
        if let snapshot = ComponentType.snapshots.first(where: { $0.name == snapshotName}) {
            self.snapshot = snapshot
            return
        }
        for test in ComponentType.tests {
            let state = ComponentType.state(for: test)
            let model = ViewModel<ComponentType.Model>(state: state, environment: test.environment)
            let result = await model.runTest(test, initialState: state, assertions: [], delay: 0, sendEvents: false)
            for snapshot in result.snapshots {
                if snapshot.name == snapshotName {
                    self.snapshot = snapshot
                    return
                }
            }
        }
    }

    var body: some View {
        ZStack {
            if let snapshot {
                ComponentType.view(model: snapshot.viewModel())
            } else {
                ProgressView()
                    .task { await generateSnapshot() }
            }
        }
    }
}

struct ComponentSnapshotView_Previews: PreviewProvider {
    static var previews: some View {
        ComponentSnapshotView<ExampleComponent>(snapshotName: "tapped")
    }
}
