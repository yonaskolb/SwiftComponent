import Foundation
import SwiftUI
import CasePaths
import Dependencies

@dynamicMemberLookup
public class ModelContext<Model: ComponentModel> {

    weak var store: ComponentStore<Model>!

    init(store: ComponentStore<Model>) {
        self.store = store
    }

    @MainActor public var state: Model.State { store.state }

    @MainActor
    public subscript<Value>(dynamicMember keyPath: WritableKeyPath<Model.State, Value>) -> Value {
        get {
            store.state[keyPath: keyPath]
        }
        set {
            // TODO: can't capture source location
            // https://forums.swift.org/t/add-default-parameter-support-e-g-file-to-dynamic-member-lookup/58490/2
            store.mutate(keyPath, value: newValue, source: nil)
        }
    }

    // so we can access read only properties
    @MainActor
    public subscript<Value>(dynamicMember keyPath: KeyPath<Model.State, Value>) -> Value {
        store.state[keyPath: keyPath]
    }
}
