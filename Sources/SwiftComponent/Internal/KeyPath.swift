//
//  File.swift
//  
//
//  Created by Yonas Kolb on 18/10/2022.
//

import Foundation
@_implementationOnly import Runtime

extension KeyPath {

    var propertyName: String? {
        guard let offset = MemoryLayout<Root>.offset(of: self) else {
            return nil
        }
        guard let info = try? typeInfo(of: Root.self) else {
            return nil
        }

        func getPropertyName(for info: TypeInfo, baseOffset: Int, path: [String]) -> String? {
            for property in info.properties {
                // Make sure to check the type as well as the offset. In the case of
                // something like \Foo.bar.baz, if baz is the first property of bar, they
                // will have the same offset since it will be at the top (offset 0).
                if property.offset == offset - baseOffset && property.type == Value.self {
                    return (path + [property.name]).joined(separator: ".")
                }

                guard let propertyTypeInfo = try? typeInfo(of: property.type) else { continue }

                let trueOffset = baseOffset + property.offset
                let byteRange = trueOffset..<(trueOffset + propertyTypeInfo.size)

                if byteRange.contains(offset) {
                    // The property is not this property but is within the byte range used by the value.
                    // So check its properties for the value at the offset.
                    return getPropertyName(
                        for: propertyTypeInfo,
                        baseOffset: property.offset + baseOffset,
                        path: path + [property.name]
                    )
                }
            }

            return nil
        }

        return getPropertyName(for: info, baseOffset: 0, path: [])
    }
}
