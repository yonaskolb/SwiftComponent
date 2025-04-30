import Foundation

public protocol ComponentEnvironment {
    associatedtype Parent
    associatedtype ID: Hashable
    var parent: Parent { get }
    static var preview: Self { get }
}

public struct EmptyEnvironment: ComponentEnvironment {
    public typealias ID = String
    public var parent: Void = ()
    public static var preview: EmptyEnvironment { .init() }
}
