//
//  File.swift
//  
//
//  Created by Yonas Kolb on 18/10/2022.
//

import Foundation
import CustomDump

extension String {
    public func indent(by indent: Int) -> String {
        let indentation = String(repeating: " ", count: indent)
        return indentation + self.replacingOccurrences(of: "\n", with: "\n\(indentation)")
    }
}

func dump(_ value: Any) -> String {
    var string = ""
    customDump(value, to: &string)
    return string
}

func dumpLine(_ value: Any) -> String {
    //TODO: do custom dumping to one line
    var string = dump(value)
    // remove type wrapper
    string = string.replacingOccurrences(of: #"^\S*\(\s*([\s\S]*?)\s*\)"#, with: "$1", options: .regularExpression)
    // remove newlines
    string = string.replacingOccurrences(of: #"\n\s*( )"#, with: "$1", options: .regularExpression)
    return string
}

