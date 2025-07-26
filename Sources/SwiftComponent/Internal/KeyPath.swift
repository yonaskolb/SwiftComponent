import Foundation
@_implementationOnly import Runtime

extension KeyPath {

    // swift 5.8 has a debugDescription on KeyPath, and even works with getters, but it doesn't work with index lookups
    // We can use mirror as a fallback but it doesn't work with getters or indices
    // TODO: enable Item.array[0].string to be "array[0].string" somehow. For now just do array.string
    var propertyName: String? {
#if swift(>=5.8)
        if #available(iOS 16.4, macOS 13.3, *) {
            // Is in format "\State.standup.name" so drop the slash and type
            let debugDescriptionResult = debugDescription
                .dropFirst() // drop slash
                .split(separator: ".")
                .filter { !($0.hasPrefix("<computed") && $0.hasSuffix(">")) }
                .dropFirst() // drop State
                .joined(separator: ".")
                .replacingOccurrences(of: ".subscript(_: Int)", with: "")
                .replacingOccurrences(of: "<Unknown>", with: "_")
                .replacingOccurrences(of: #"^\$"#, with: "", options: .regularExpression) // drop leading $
                .replacingOccurrences(of: #"\?$"#, with: "", options: .regularExpression) // drop trailing ?
            
            // If debugDescription parsing resulted in empty string (likely due to computed properties),
            // fall back to Runtime-based approach
            if !debugDescriptionResult.isEmpty {
                return debugDescriptionResult
            } else {
                return mirrorPropertyName
            }
        } else {
            return mirrorPropertyName
        }
#else
        mirrorPropertyName
#endif
    }

    private var mirrorPropertyName: String? {
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
