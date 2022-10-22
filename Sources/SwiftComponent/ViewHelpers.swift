//
//  File.swift
//  
//
//  Created by Yonas Kolb on 16/10/2022.
//

import Foundation
import SwiftUI

extension ViewModel {

    public func actionButton<Label: View>(_ action: C.Action, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line, @ViewBuilder label: () -> Label) -> some View {
        Button(action: { self.send(action, file: file, fileID: fileID, line: line) }) { label() }
    }

    public func actionButton(_ action: C.Action, _ text: LocalizedStringKey, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line) -> some View {
        actionButton(action, file: file, fileID: fileID, line: line) { Text(text) }
    }
}

/// Used to easily dismiss a view. Will not work inside a toolbar
public struct DismissButton<Label: View>: View {

    @Environment(\.dismiss) var dismiss
    var label: Label

    public init(@ViewBuilder label: () -> Label) {
        self.label = label()
    }

    public var body: some View {
        Button(action: { dismiss() }) { label }
    }
}

extension View {

    func interactiveBackground() -> some View {
        contentShape(Rectangle())
    }

    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}
