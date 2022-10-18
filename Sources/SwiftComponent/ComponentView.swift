//
//  File.swift
//  
//
//  Created by Yonas Kolb on 18/10/2022.
//

import Foundation
import SwiftUI

public protocol ComponentView: View {

    associatedtype C: Component
    associatedtype ComponentView : View
    var model: ViewModel<C> { get }
    init(model: ViewModel<C>)
    @ViewBuilder @MainActor var view: Self.ComponentView { get }
}

public extension ComponentView {

    @MainActor
    var body: some View {
        VStack {
            ForEach(model.viewModes) { viewMode in
                switch viewMode {
                    case .view: view
                    case .data:
                        ScrollView(.vertical) {
                            Text(model.stateDump)
                        }
                    case .history:
                        List {
                            ForEach(model.events) { event in
                                VStack {
                                    Text(event.event.title)
                                        .bold()
                                    Text(event.event.details)
                                        .lineLimit(2)
                                    Spacer()
                                }
                            }
                        }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            withAnimation {
                switch model.viewModes {
                    case [.view]:
                        model.viewModes = [.data]
                    case [.data]:
                        model.viewModes = [.history]
                    case [.history]:
                        model.viewModes = [.view]
//                    case [.view]:
//                        model.viewModes = [.view, .data]
//                    case [.view, .data]:
//                        model.viewModes = [.data]
//                    case [.data]:
//                        model.viewModes = [.data, .view]
//                    case [.data, .view]:
//                        model.viewModes = [.view]
                    default:
                        break
                }
            }
        }
        .task { await model.task() }
//        .background {
//            NavigationLink(isActive: Binding(get: { model.route?.mode == .push }, set: { present in
//                if !present {
//                    model.route = nil
//                }
//            })) {
//                routeView()
//            } label: {
//                EmptyView()
//            }
//        }
//        .sheet(isPresented: Binding(get: { model.route?.mode == .sheet }, set: { present in
//            if !present {
//                model.route = nil
//            }
//        })) {
//            routeView()
//        }
    }


    @ViewBuilder
    func routeView() -> some View {
        if let route = model.route {
            if route.inNav {
                NavigationView { route.component }
            } else {
                route.component
            }
        } else {
            EmptyView()
        }
    }

    func task() async {

    }

    func binding<Value>(_ keyPath: WritableKeyPath<C.State, Value>) -> Binding<Value> {
        model.binding(keyPath)
    }

    var state: C.State { model.state }
}
