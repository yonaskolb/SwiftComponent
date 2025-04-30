import Foundation

public protocol ComponentEnvironment {
    associatedtype Parent
    var parent: Parent { get }
    static var preview: Self { get }
    /// provide a copy of the environment. If this is a class it must be a new instance. This is used for snapshots and test branch resets
    func copy() -> Self
}

public struct EmptyEnvironment: ComponentEnvironment {
    public var parent: Void = ()
    public static var preview: EmptyEnvironment { .init() }
    public func copy() -> EmptyEnvironment { .init() }
}
