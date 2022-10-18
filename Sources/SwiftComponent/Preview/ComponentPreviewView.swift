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

    public init(components: [ComponentInfo], views: [ViewItem]) {
        self.components = components
        self.views = views
        let component = components.first!
        let view = ViewItem(component.view, name: component.name)
        self._view = State(initialValue: view)
        self._component = State(initialValue: component)
        self._state = State(initialValue: component.states.first!)
    }

    public init(component: ComponentInfo) {
        self.components = []
        self.views = []
        self._component = State(initialValue: component)
        self._view = State(initialValue: ViewItem(component.view, name: component.name))
        self._state = State(initialValue: component.states.first!)
    }

    let iconScale: CGFloat = 0.2
    let iconWidth = Device.iPhoneSE.size.width
    let iconHeight = Device.iPhoneSE.size.width*1.3

    func select(_ component: ComponentInfo) {
        withAnimation {
            self.view = ViewItem(component.view, name: component.name)
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
                    Section(header: Text("Components")) {
                        componentsList
                    }
                    Section(header: Text("Other Views")) {
                        viewsList
                    }
                }
                .listStyle(.grouped)
                .frame(width: 250)
                Divider()
            }
            ZStack {
                if let view = view {
                    ViewPreviewer(content: view.view, name: view.name)
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
        .edgesIgnoringSafeArea(.all)
        .navigationViewStyle(StackNavigationViewStyle())
        .previewDevice("iPad Pro (12.9-inch) (5th generation)")
    }

    var componentsList: some View {
        ForEach(components.sorted { $0.name < $1.name }) { component in
            Button(action: { select(component) }) {
                viewItem(ViewItem(component.view, name: component.name), states: component.states)
            }
            .buttonStyle(.plain)
//            .listRowBackground(self.view?.name == component.name ? Color.neutral90 : Color.systemBackground)
        }
    }

    var viewsList: some View {
        ForEach(views.sorted { $0.name < $1.name }) { view in
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
//                .background(.systemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .shadow(radius: 2)
            VStack(alignment: .leading) {
                Spacer()
                Text(view.name.replacingOccurrences(of: "View", with: ""))
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
    public let name: String
    public let view: AnyView

    public init<V: View>(_ view: V, name: String? = nil) {
        self.name = name ?? String(describing: V.self)
        self.view = view.eraseToAnyView()
    }
}

extension ComponentPreview {

    public static func componentPreview() -> some View {
        ComponentPreviewView(component: componentInfo)
    }
}

#endif
