//
//  File.swift
//  
//
//  Created by Yonas Kolb on 18/10/2022.
//

import Foundation
import SwiftUI

#if DEBUG

public struct ComponentPreviewView: View {
    let components: [ComponentInfo]
    let views: [ViewItem]

    @State var view: ViewItem?
    @State var component: ComponentInfo?
    @State var state: String?
    @State var render = UUID()

    var hasList: Bool {
        !components.isEmpty || !views.isEmpty
    }

    public init(components: [ComponentInfo], views: [ViewItem] = []) {
        self.components = components
        self.views = views
        let component = components.first!
        let view = ViewItem(component.view, componentName: component.componentName)
        self._view = State(initialValue: view)
        self._component = State(initialValue: component)
        self._state = State(initialValue: component.states.first!)
    }

    public init(component: ComponentInfo) {
        self.components = []
        self.views = []
        self._component = State(initialValue: component)
        self._view = State(initialValue: ViewItem(component.view, componentName: component.componentName))
        self._state = State(initialValue: component.states.first!)
    }

    let iconScale: CGFloat = 0.2
    let iconWidth = Device.iPhoneSE.width
    let iconHeight = Device.iPhoneSE.width*1.3

    func select(_ component: ComponentInfo) {
        withAnimation {
            self.view = ViewItem(component.view, componentName: component.componentName)
            self.component = component
            self.state = component.states.first
        }
    }

    func select(_ view: ViewItem) {
        withAnimation {
            self.view = view
            self.component = nil
            self.state = nil
        }
    }

    public var body: some View {
        HStack(spacing: 0) {
            if hasList {
                List {
                    if !components.isEmpty {
                        Section(header: Text("Components")) {
                            componentsList
                        }
                    }
                    if !views.isEmpty {
                        Section(header: Text("Views")) {
                            viewsList
                        }
                    }
                }
                .listStyle(.grouped)
                .frame(width: 250)
                Divider()
            }
            ZStack {
                if let view = view {
                    ViewPreviewer(content: view.view, name: view.componentName)
                        .padding()
                } else {
                    emptyView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let component = component {
                HStack(spacing: 0) {
                    Divider()
                    ComponentInfoView(component: component, state: $state)
                }
                .animation(.default)
                .transition(.move(edge: .trailing))
            }
        }
        //.edgesIgnoringSafeArea(.all)
        .navigationViewStyle(StackNavigationViewStyle())
        .previewDevice(.iPadLargest)
    }

    var componentsList: some View {
        ForEach(components.sorted { $0.componentName < $1.componentName }) { component in
            Button(action: { select(component) }) {
                VStack(alignment: .leading) {
                    Text(component.componentName)
                        .bold()
                    Text(component.viewName)
                }
//                viewItem(ViewItem(component.view, componentName: component.componentName), states: component.states)
            }
            .buttonStyle(.plain)
//            .listRowBackground(self.view?.name == component.name ? Color.neutral90 : Color.systemBackground)
        }
    }

    var viewsList: some View {
        ForEach(views.sorted { $0.componentName < $1.componentName }) { view in
            Button(action: { select(view) }) {
                viewItem(view)
            }
            .buttonStyle(.plain)
//            .listRowBackground(self.view?.name == view.name ? Color.neutral90 : Color.systemBackground)
        }
    }

    func viewItem(_ view: ViewItem, states: [String] = []) -> some View {
        HStack(spacing: 12) {
            view
                .view
                .allowsHitTesting(false)
                .frame(width: iconWidth, height: iconHeight)
                .scaleEffect(iconScale)
                .frame(width: iconWidth*iconScale, height: iconHeight*iconScale)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .shadow(radius: 2)
            VStack(alignment: .leading) {
                Spacer()
                Text(view.componentName.replacingOccurrences(of: "View", with: ""))
                    .font(.subheadline)
                    .bold()
//                    .color(self.view?.name == view.name ? .white : .neutral90)
                Spacer()
                Spacer()
            }
            Spacer()
        }
        .interactiveBackground()
    }

    var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "list.bullet.below.rectangle")
                .font(.system(size: 80, weight: .thin))
            Text("Select a view")
                .font(.title)
            Spacer()
            Spacer()
        }
        .foregroundColor(.gray)
    }
}

public struct ViewItem: Identifiable {
    public let id = UUID()
    public let componentName: String
    public let view: AnyView

    public init<V: View>(_ view: V, componentName: String? = nil) {
        self.componentName = componentName ?? String(describing: V.self)
        self.view = view.eraseToAnyView()
    }
}

extension ComponentPreview {

    public static func componentPreview() -> some View {
        ComponentPreviewView(component: componentInfo)
    }
}

struct ComponentPreview_Previews: PreviewProvider {

    static var previews: some View {
        ExamplePreview.componentPreview()
    }
}

#endif
