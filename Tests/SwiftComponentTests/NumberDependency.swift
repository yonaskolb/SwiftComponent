import Dependencies

struct NumberDependency {
    let value: Int
    
    func callAsFunction() -> Int {
        value
    }
}

extension NumberDependency: ExpressibleByIntegerLiteral {
    
    init(integerLiteral value: IntegerLiteralType) {
        self.value = value
    }
}

extension NumberDependency: DependencyKey {
    static var liveValue = NumberDependency(value: 1)
    static var testValue = NumberDependency(value: 0)
}

extension DependencyValues {
    var number: NumberDependency {
        get { self[NumberDependency.self] }
        set { self[NumberDependency.self] = newValue }
    }
}
