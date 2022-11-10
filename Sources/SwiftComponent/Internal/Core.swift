import Foundation
import CustomDump

extension String {
    public func indent(by indent: Int) -> String {
        let indentation = String(repeating: " ", count: indent)
        return indentation + self.replacingOccurrences(of: "\n", with: "\n\(indentation)")
    }
}

func dumpToString(_ value: Any) -> String {
    var string = ""
    customDump(value, to: &string)
    return string
}

func dumpLine(_ value: Any) -> String {
    //TODO: do custom dumping to one line
    var string = dumpToString(value)
    // remove type wrapper
    string = string.replacingOccurrences(of: #"^\S*\(\s*([\s\S]*?)\s*\)"#, with: "$1", options: .regularExpression)
    // remove newlines
    string = string.replacingOccurrences(of: #"\n\s*( )"#, with: "$1", options: .regularExpression)
    return string
}

/// returns true if lhs and rhs are equatable and are equal
func areMaybeEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    if let lhs = lhs as? any Equatable {
        if areEqual(lhs, rhs) {
            return true
        }
    }
    return false
}

func areEqual<A: Equatable>(_ lhs: A, _ rhs: Any) -> Bool {
    lhs == (rhs as? A)
}
