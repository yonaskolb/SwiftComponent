//
//  File.swift
//  
//
//  Created by Yonas Kolb on 16/10/2022.
//

import Foundation
import SwiftUI

extension ViewModel {

    public func inputButton<Label: View>(_ input: Model.Input, animation: Animation? = nil, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line, @ViewBuilder label: () -> Label) -> some View {
        Button(action: {
            if let animation = animation {
                withAnimation(animation) {
                    self.send(input, file: file, fileID: fileID, line: line)
                }
            } else {
                self.send(input, file: file, fileID: fileID, line: line)
            }
        }) { label() }
    }

    public func inputButton(_ input: Model.Input, animation: Animation? = nil, _ text: LocalizedStringKey, file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line) -> some View {
        inputButton(input, animation: animation, file: file, fileID: fileID, line: line) { Text(text) }
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
