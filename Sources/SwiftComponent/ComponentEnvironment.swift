import Foundation

public protocol ComponentEnvironment {
    associatedtype Parent
    associatedtype State = Void
    var parent: Parent { get }
    var state: State { get set }
    static var preview: Self { get }
}

extension ComponentEnvironment where State == Void {
    public var state: State { () }
}

public struct EmptyEnvironment: ComponentEnvironment {
    public var parent: Void = ()
    public static var preview: EmptyEnvironment { .init() }
}
