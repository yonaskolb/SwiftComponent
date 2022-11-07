//
//  File.swift
//  
//
//  Created by Yonas Kolb on 18/10/2022.
//

import Foundation
import SwiftUI
import SwiftGUI
import SwiftPreview

public protocol ComponentView: View {

    associatedtype Model: ComponentModel
    associatedtype ComponentView : View
    var model: ViewModel<Model> { get }
    init(model: ViewModel<Model>)
    @ViewBuilder @MainActor var view: Self.ComponentView { get }
}

struct ComponentViewContainer<Model: ComponentModel, Content: View>: View {

    let model: ViewModel<Model>
    let view: Content
    @State var showDebug = false
    @State var viewModes: [ComponentViewMode] = [.view]
    @Environment(\.isPreviewReference) var isPreviewReference

    enum ComponentViewMode: String, Identifiable {
        case view
        case data
        case history
        case editor
        case debug

        var id: String { rawValue }
    }

    var body: some View {
        view
        .task { @MainActor in
            // don't call this for other reference views
            if !isPreviewReference {
                await model.task()
            }
        }
#if DEBUG
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            showDebug = !showDebug
        }
        .sheet(isPresented: $showDebug) {
            if #available(iOS 16.0, *) {
                ComponentDebugView(viewModel: model)
                    .presentationDetents([.medium, .large])
            } else {
                ComponentDebugView(viewModel: model)
            }
        }
#endif
    }
}

public extension ComponentView {

    @MainActor
    var body: some View {
        ComponentViewContainer(model: model, view: view)
    }

    func task() async {

    }

    func binding<Value>(_ keyPath: WritableKeyPath<Model.State, Value>) -> Binding<Value> {
        model.binding(keyPath)
    }

    var state: Model.State { model.state }
}
