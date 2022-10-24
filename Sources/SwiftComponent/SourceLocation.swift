//
//  File.swift
//  
//
//  Created by Yonas Kolb on 21/10/2022.
//

import Foundation

public struct SourceLocation: Hashable {
    public let file: String
    public let fileID: String
    public let line: UInt


    public static func capture(file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line) -> Self {
        SourceLocation(file: file.description, fileID: file.description, line: line)
    }
}
