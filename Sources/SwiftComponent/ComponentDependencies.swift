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
}
