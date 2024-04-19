import Foundation
import SwiftUI
import SwiftGUI
import SwiftPreview

public protocol ComponentView: View, DependencyContainer {

    associatedtype Model: ComponentModel
    associatedtype ComponentView: View
    associatedtype DestinationView: View
    associatedtype Style = Never
    typealias Input = Model.Input
    typealias Output = Model.Output
    var model: ViewModel<Model> { get }
    @ViewBuilder @MainActor var view: Self.ComponentView { get }
    @ViewBuilder @MainActor func view(route: Model.Route) -> DestinationView
    @MainActor func presentation(route: Model.Route) -> Presentation
}

public extension ComponentView {

    func presentation(route: Model.Route) -> Presentation {
        .sheet
    }

    @MainActor
    var dependencies: ComponentDependencies { model.dependencies }
    @MainActor
    var environment: Model.Environment { model.environment }
}

public extension ComponentView where Model.Route == Never {
    func view(route: Model.Route) -> EmptyView {
        EmptyView()
    }
}

struct ComponentViewContainer<Model: ComponentModel, Content: View>: View {

    let model: ViewModel<Model>
    let view: Content
    @State var hasAppeared = false
    @State var showDebug = false
    @State var viewModes: [ComponentViewMode] = [.view]
    @Environment(\.viewAppearanceTask) var viewAppearanceTask
    @Environment(\.presentationMode) private var presentationMode

    enum ComponentViewMode: String, Identifiable {
        case view
        case data
        case history
        case editor
        case debug

        var id: String { rawValue }
    }

    @MainActor
    func getView() -> some View {
        model.store.setPresentationMode(presentationMode)
#if DEBUG
        let start = Date()
        let view = self.view
        model.bodyAccessed(start: start)
        return view
#else
        return self.view
#endif
    }

    var body: some View {
        getView()
        .environment(\.viewAppearanceTask, true)
        .task {
            // even though we can manage an appearanceTask in the store, use task instead of onAppear here as there can be race conditions in SwiftUI related to FocusState which means ComponentStore can be deinitialised (as a parent recreated a ViewModel) before the task actually starts.
            if viewAppearanceTask {
                let first = !hasAppeared
                hasAppeared = true
                await model.appearAsync(first: first)
            }
        }
        .onDisappear {
            if viewAppearanceTask {
                model.disappear()
            }
        }
#if DEBUG
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            showDebug = !showDebug
        }
        .sheet(isPresented: $showDebug) {
            if #available(iOS 16.0, macOS 13.0, *) {
                debugSheet
                    .presentationDetents([.medium, .large])
            } else {
                debugSheet
            }
        }
#endif
    }

    var debugSheet: some View {
        ComponentDebugSheet(model: model)
    }
}

extension ComponentView {

    @MainActor
    private var currentPresentation: Presentation? {
        model.route.map { presentation(route: $0) }
    }

    @MainActor
    private func presentationBinding(_ presentation: Presentation) -> Binding<Bool> {
        Binding(
            get: {
                currentPresentation == presentation
            },
            set: { present in
                if currentPresentation == presentation, !present, self.model.route != nil {
                    self.model.route = nil
                }
            }
        )
    }

    @MainActor
    public var body: some View {
        ComponentViewContainer(model: model, view: view)
            .push(isPresented: presentationBinding(.push)) {
                if let route = model.route {
                    view(route: route)
                }
            }
            .sheet(isPresented: presentationBinding(.sheet)) {
                if let route = model.route {
                    view(route: route)
                }
            }
        #if os(iOS)
            .fullScreenCover(isPresented: presentationBinding(.fullScreenCover)) {
                if let route = model.route {
                    view(route: route)
                }
            }
        #endif
    }

    public func onOutput(_ handle: @escaping (Model.Output) -> Void) -> Self {
        _ = model.store.onEvent { event in
            if case let .output(output) = event.type, let output = output as? Model.Output {
                handle(output)
            }
        }
        return self
    }
}

extension View {

    @ViewBuilder
    func push<Content: View>(isPresented: Binding<Bool>, @ViewBuilder destination: () -> Content) -> some View {
        if #available(iOS 16.0, macOS 13.0, *), !Presentation.useNavigationViewOniOS16 {
            self.navigationDestination(isPresented: isPresented, destination: destination)
        } else {
           self.background {
                NavigationLink(isActive: isPresented) {
                    destination()
                } label: {
                    EmptyView()
                }
           }
        }
    }
}
