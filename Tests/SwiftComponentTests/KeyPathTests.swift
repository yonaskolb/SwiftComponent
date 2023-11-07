import Foundation
import XCTest
@testable import SwiftComponent

class KeyPathTests: XCTestCase {
    
    func testPropertyName() {
        XCTAssertEqual((\Item.string as KeyPath).propertyName, "string")
        XCTAssertEqual((\Item.stringOptional as KeyPath).propertyName, "stringOptional")
        XCTAssertEqual((\Item.stringGetter as KeyPath).propertyName, "stringGetter")
        XCTAssertEqual((\Item.array[0].string as KeyPath).propertyName, "array.string")
        XCTAssertEqual((\Item.arrayGetter[0].string as KeyPath).propertyName, "arrayGetter.string")
        XCTAssertEqual((\Item.child.string as KeyPath).propertyName, "child.string")
        XCTAssertEqual((\Item.child.array[1].string as KeyPath).propertyName, "child.array.string")
        XCTAssertEqual((\Item.childOptional?.string as KeyPath).propertyName, "childOptional?.string")
        XCTAssertEqual((\Item.childGetter.string as KeyPath).propertyName, "childGetter.string")
    }

    struct Item {
        var string: String
        var stringOptional: String?
        var stringGetter: String { string }
        var array: [Child]
        var arrayGetter: [Child] { array }
        var child: Child
        var childOptional: Child?
        var childGetter: Child { child }

    }

    struct Child {
        var string: String
        var array: [Child]
    }
}
