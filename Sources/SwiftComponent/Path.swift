import Foundation

public struct ComponentPath: CustomStringConvertible, Equatable, Hashable {
    public static func == (lhs: ComponentPath, rhs: ComponentPath) -> Bool {
        lhs.string == rhs.string
    }

    public var suffix: String?
    public let path: [any ComponentModel.Type]

    var pathString: String {
        path.map { $0.baseName }.joined(separator: "/")
    }

    public var string: String {
        var string = pathString
        if let suffix {
            string += "\(suffix)"
        }
        return string
    }

    public var description: String { string }

    init(_ component: any ComponentModel.Type) {
        self.path = [component]
    }

    init(_ path: [any ComponentModel.Type]) {
        self.path = path
    }

    func contains(_ path: ComponentPath) -> Bool {
        self.pathString.hasPrefix(path.pathString)
    }

    func appending(_ component: any ComponentModel.Type) -> ComponentPath {
        ComponentPath(path + [component])
    }

    var parent: ComponentPath? {
        if path.count > 1 {
            return ComponentPath(path.dropLast())
        } else {
            return nil
        }
    }

    func relative(to component: ComponentPath) -> ComponentPath {
        guard contains(component) else { return self }
        let difference = path.count - component.path.count
        return ComponentPath(Array(path.dropFirst(difference)))
    }

    var droppingRoot: ComponentPath? {
        if !path.isEmpty {
            return ComponentPath(Array(path.dropFirst()))
        } else {
            return nil
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(pathString)
    }
}
