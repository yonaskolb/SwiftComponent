//
//  File.swift
//  
//
//  Created by Yonas Kolb on 18/10/2022.
//

import Foundation

struct EnumCase {
    let name: String
    let values: [String: Any]
}

func getEnumCase<T>(_ enumValue: T) -> EnumCase {
    let reflection = Mirror(reflecting: enumValue)
    guard reflection.displayStyle == .enum,
        let associated = reflection.children.first else {
        return EnumCase(name: "\(enumValue)", values: [:])
    }
    let valuesChildren = Mirror(reflecting: associated.value).children
    var values = [String: Any]()
    for case let item in valuesChildren where item.label != nil {
        values[item.label!] = item.value
    }
    return EnumCase(name: associated.label!, values: values)
}
