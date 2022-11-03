//
//  File.swift
//  
//
//  Created by Yonas Kolb on 21/10/2022.
//

import Foundation

public struct SourceLocation: Hashable {
    public static func == (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
        lhs.file.description == rhs.file.description && lhs.fileID.description == rhs.fileID.description && lhs.line == rhs.line
    }

    public let file: StaticString
    public let fileID: StaticString
    public let line: UInt

    public func hash(into hasher: inout Hasher) {
        hasher.combine(file.description)
        hasher.combine(fileID.description)
        hasher.combine(line)
    }


    public static func capture(file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line) -> Self {
        SourceLocation(file: file, fileID: file, line: line)
    }
}
