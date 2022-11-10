//
//  File.swift
//  
//
//  Created by Yonas Kolb on 21/10/2022.
//

import Foundation

public struct Source: Hashable {
    public static func == (lhs: Source, rhs: Source) -> Bool {
        lhs.file.description == rhs.file.description && lhs.line == rhs.line
    }

    public let file: StaticString
    public let line: UInt

    public func hash(into hasher: inout Hasher) {
        hasher.combine(file.description)
        hasher.combine(line)
    }


    public static func capture(file: StaticString = #file, line: UInt = #line) -> Self {
        Source(file: file, line: line)
    }
}
