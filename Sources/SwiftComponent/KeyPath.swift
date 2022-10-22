//
//  File.swift
//  
//
//  Created by Yonas Kolb on 18/10/2022.
//

import Foundation
import Runtime

extension KeyPath {

    var propertyName: String? {

        guard let offset = MemoryLayout<Root>.offset(of: self) else {
            return nil
        }
        guard let info = try? typeInfo(of: Root.self) else {
            return nil
        }

        func getPropertyName(for info: TypeInfo, path: [String]) -> String? {
            if let property = info.properties.first(where: { $0.offset == offset }) {
                return (path + [property.name]).joined(separator: ".")
            } else {
                for property in info.properties {
                    if let info = try? typeInfo(of: property.type),
                       let propertyName = getPropertyName(for: info, path: path + [property.name]) {
                        return propertyName
                    }
                }
                return nil
            }
        }
        return getPropertyName(for: info, path: [])
    }
}
