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
