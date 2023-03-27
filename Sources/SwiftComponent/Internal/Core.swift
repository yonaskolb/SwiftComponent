import Foundation
import CustomDump

extension String {
    func indent(by indent: Int) -> String {
        let indentation = String(repeating: " ", count: indent)
        return indentation + self.replacingOccurrences(of: "\n", with: "\n\(indentation)")
    }

    var quoted: String { "\"\(self)\""}
}

public func dumpToString(_ value: Any, maxDepth: Int = .max) -> String {
    var string = ""
    customDump(value, to: &string, maxDepth: maxDepth)
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

struct StateDump {

    static func diff(_ old: Any, _ new: Any) -> [String]? {
        guard let diff = CustomDump.diff(old, new) else { return nil }
        let lines = diff.components(separatedBy: "\n")
        return lines
            .map { line in
                if line.hasSuffix(",") || line.hasSuffix("(") {
                    return String(line.dropLast())
                } else if line.hasSuffix(" [") {
                    return String(line.dropLast(2))
                } else {
                    return line
                }
            }
            .filter {
                let actual = $0
                    .trimmingCharacters(in: CharacterSet(charactersIn: "+"))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
                    .trimmingCharacters(in: .whitespaces)
                return actual != ")" && actual != "]"
            }
    }
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
