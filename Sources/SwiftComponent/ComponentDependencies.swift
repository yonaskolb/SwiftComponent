//
//  File.swift
//  
//
//  Created by Yonas Kolb on 15/4/2023.
//

import Foundation
import Dependencies

@dynamicMemberLookup
public struct ComponentDependencies {

    var dependencyValues: DependencyValues

    init() {
        dependencyValues = DependencyValues._current
    }

    mutating func setDependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, _ dependency: T) {
        dependencyValues[keyPath: keyPath] = dependency
    }

    public subscript<Value>(dynamicMember keyPath: KeyPath<DependencyValues, Value>) -> Value {
        let dependencies = self.dependencyValues.merging(DependencyValues._current)
        return DependencyValues.$_current.withValue(dependencies) {
            DependencyValues._current[keyPath: keyPath]
        }
    }

    mutating func apply(_ dependencies: ComponentDependencies) {
        self.dependencyValues = self.dependencyValues.merging(dependencies.dependencyValues)
    }
}

extension ViewModel {

    public func dependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, _ value: T) -> Self {
        self.store.dependencies.setDependency(keyPath, value)
        return self
    }
}

extension ComponentRoute {

    @discardableResult
    public func dependency<T>(_ keyPath: WritableKeyPath<DependencyValues, T>, _ value: T) -> Self {
        if let store {
            store.dependencies.setDependency(keyPath, value)
        } else {
            self.dependencies.setDependency(keyPath, value)
        }
        return self
    }
}
