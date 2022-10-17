//
//  File.swift
//  
//
//  Created by Yonas Kolb on 16/10/2022.
//

import Foundation
import SwiftUI

extension Store {

    public func button<Label: View>(_ action: C.Action, file: StaticString = #file, line: UInt = #line, label: () -> Label) -> some View {
        Button(action: { self.send(action, file: file, line: line) }) { label() }
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
