#if canImport(SwiftComponentMacros)
import MacroTesting
import Foundation
import XCTest
import SwiftComponentMacros

final class ResourceMacroTests: XCTestCase {
    override func invokeTest() {
        withMacroTesting(isRecording: false, macros: [ResourceMacro.self]) {
            super.invokeTest()
        }
    }

    func testResource() {
        assertMacro {
            """
            struct State {
                @Resource var item: Item?
                @Resource var item2: Item?
            }
            """
        } expansion: {
            #"""
            struct State {
                var item: Item? {
                    @storageRestrictions(initializes: _item)
                    init(initialValue) {
                        _item = ResourceState(wrappedValue: initialValue)
                    }
                    get {
                        _$observationRegistrar.access(self, keyPath: \.item)
                        return _item.wrappedValue
                    }
                    set {
                        _$observationRegistrar.mutate(self, keyPath: \.item, &_item.wrappedValue, newValue, _$isIdentityEqual)
                    }
                }

                var $item: SwiftComponent.ResourceState<Item> {
                    get {
                        _$observationRegistrar.access(self, keyPath: \.item)
                        return _item.projectedValue
                    }
                    set {
                        _$observationRegistrar.mutate(self, keyPath: \.item, &_item.projectedValue, newValue, _$isIdentityEqual)
                    }
                }

                @ObservationStateIgnored private var _item = SwiftComponent.ResourceState<Item>(wrappedValue: nil)
                var item2: Item? {
                    @storageRestrictions(initializes: _item2)
                    init(initialValue) {
                        _item2 = ResourceState(wrappedValue: initialValue)
                    }
                    get {
                        _$observationRegistrar.access(self, keyPath: \.item2)
                        return _item2.wrappedValue
                    }
                    set {
                        _$observationRegistrar.mutate(self, keyPath: \.item2, &_item2.wrappedValue, newValue, _$isIdentityEqual)
                    }
                }

                var $item2: SwiftComponent.ResourceState<Item> {
                    get {
                        _$observationRegistrar.access(self, keyPath: \.item2)
                        return _item2.projectedValue
                    }
                    set {
                        _$observationRegistrar.mutate(self, keyPath: \.item2, &_item2.projectedValue, newValue, _$isIdentityEqual)
                    }
                }

                @ObservationStateIgnored private var _item2 = SwiftComponent.ResourceState<Item>(wrappedValue: nil)
            }
            """#
        }
    }
}
#endif
