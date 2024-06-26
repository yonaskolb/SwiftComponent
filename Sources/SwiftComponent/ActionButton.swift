//
//  File.swift
//  
//
//  Created by Yonas Kolb on 30/1/2023.
//

import Foundation
import SwiftUI

extension ViewModel {

    public func button<Label: View>(_ action: @escaping @autoclosure () -> Model.Action, file: StaticString = #filePath, line: UInt = #line, @ViewBuilder label: () -> Label) -> some View {
        ActionButtonView(model: self, action: action, file: file, line: line, label: label)
    }

    public func button(_ action: @escaping @autoclosure () -> Model.Action, _ text: LocalizedStringKey, file: StaticString = #filePath, line: UInt = #line) -> some View {
        ActionButtonView(model: self, action: action, file: file, line: line) { Text(text) }
    }

    public func button(_ action: @escaping @autoclosure () -> Model.Action, _ text: String, file: StaticString = #filePath, line: UInt = #line) -> some View {
        ActionButtonView(model: self, action: action, file: file, line: line) { Text(text) }
    }
}

extension ComponentView {

    public func button<Label: View>(_ action: @escaping @autoclosure () -> Model.Action, file: StaticString = #filePath, line: UInt = #line, @ViewBuilder label: () -> Label) -> some View {
        ActionButtonView(model: model, action: action, file: file, line: line, label: label)
    }

    public func button(_ action: @escaping @autoclosure () -> Model.Action, _ text: LocalizedStringKey, file: StaticString = #filePath, line: UInt = #line) -> some View {
        ActionButtonView(model: model, action: action, file: file, line: line) { Text(text) }
    }

    public func button(_ action: @escaping @autoclosure () -> Model.Action, _ text: String, file: StaticString = #filePath, line: UInt = #line) -> some View {
        ActionButtonView(model: model, action: action, file: file, line: line) { Text(text) }
    }
}

fileprivate class DispatchWorkContainer {
    var work: DispatchWorkItem?
}

private struct ShowActionButtonFlashKey: EnvironmentKey {

    static var defaultValue: Bool = false
}

extension EnvironmentValues {

    public var showActionButtonFlash: Bool {
        get {
            self[ShowActionButtonFlashKey.self]
        }
        set {
            self[ShowActionButtonFlashKey.self] = newValue
        }
    }
}

struct ActionButtonView<Model: ComponentModel, Label: View>: View {

    @State var actioned = false
    @Environment(\.showActionButtonFlash) var showActionButtonFlash
    let dismissAfter: TimeInterval = 0.3

    /// Reference to dispatch work, to be able to cancel it when needed
    @State fileprivate var dispatchWorkContainer = DispatchWorkContainer()

    var model: ViewModel<Model>
    var action: () -> Model.Action
    var file: StaticString
    var line: UInt
    var label: Label

    init(
        model: ViewModel<Model>,
        action: @escaping () -> Model.Action,
        file: StaticString = #filePath,
        line: UInt = #line,
        @ViewBuilder label: () -> Label) {
            self.model = model
            self.action = action
            self.file = file
            self.line = line
            self.label = label()
        }

    func didAction() {
        actioned = true
        dispatchWorkContainer.work?.cancel()
        dispatchWorkContainer.work = DispatchWorkItem(block: { actioned = false })

        if let work = dispatchWorkContainer.work {
            DispatchQueue.main.asyncAfter(deadline: .now() + dismissAfter, execute: work)
        }
    }

    var body: some View {
        Button {
            model.send(action(), file: file, line: line)
        } label: { label }
#if DEBUG
            .accessibility(hint: Text("action: \(getEnumCase(action()).name)"))
            //.accessibilityCustomContent("swift.component.action", getEnumCase(action()).name, importance: .high) // AccessibilitySnapshot doesn't seem to pick this up. Yet?
            .onReceive(EventStore.shared.eventPublisher) { event in
                guard showActionButtonFlash else { return }
                switch event.type {
                    case .action(let eventAction):
                        guard let eventAction = eventAction as? Model.Action
                        else { return }
                        if areMaybeEqual(action, eventAction) {
                            didAction()
                        } else {
                            if String(describing: action) == String(describing: eventAction) {
                                didAction()
                            }
                        }
                    default: break
                }
            }
            .overlay {
                if actioned {
                    Color.red.opacity(actioned ? 0.3 : 0)
                        .animation(.default, value: actioned)
                }
            }
#endif
    }
}
