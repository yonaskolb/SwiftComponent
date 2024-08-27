import Foundation

public protocol ComponentEnvironment {
    associatedtype Parent
    var parent: Parent { get }
    static var preview: Self { get }
}

public struct EmptyEnvironment: ComponentEnvironment {
    public var parent: Void = ()
    public static var preview: EmptyEnvironment { .init() }
}
