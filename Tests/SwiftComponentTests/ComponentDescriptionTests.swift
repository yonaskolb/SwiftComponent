import Foundation
import XCTest
import InlineSnapshotTesting
@testable import SwiftComponent

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class ComponentDescriptionTests: XCTestCase {
    
    func testDescriptionParsing() throws {
        let description = try ComponentDescription(type: ExampleComponent.self)
        
        assertInlineSnapshot(of: description, as: .json) {
            """
            {
              "component" : {
                "name" : "ExampleComponent",
                "states" : [

                ],
                "tests" : [
                  "Set date",
                  "Fill out",
                  "Open child"
                ]
              },
              "model" : {
                "action" : {
                  "enumType" : {
                    "_0" : [
                      {
                        "name" : "tap",
                        "payloads" : [
                          "Int"
                        ]
                      },
                      {
                        "name" : "open",
                        "payloads" : [

                        ]
                      }
                    ]
                  }
                },
                "connections" : {
                  "structType" : {
                    "_0" : [
                      {
                        "name" : "child",
                        "type" : "ExampleChildModel"
                      },
                      {
                        "name" : "connectedChild",
                        "type" : "ExampleChildModel"
                      },
                      {
                        "name" : "presentedChild",
                        "type" : "ExampleChildModel"
                      }
                    ]
                  }
                },
                "input" : {
                  "enumType" : {
                    "_0" : [
                      {
                        "name" : "child",
                        "payloads" : [
                          "Output"
                        ]
                      }
                    ]
                  }
                },
                "name" : "ExampleModel",
                "output" : {
                  "enumType" : {
                    "_0" : [
                      {
                        "name" : "finished",
                        "payloads" : [

                        ]
                      },
                      {
                        "name" : "unhandled",
                        "payloads" : [

                        ]
                      }
                    ]
                  }
                },
                "route" : {
                  "enumType" : {
                    "_0" : [

                    ]
                  }
                },
                "state" : {
                  "structType" : {
                    "_0" : [
                      {
                        "name" : "name",
                        "type" : "String"
                      },
                      {
                        "name" : "loading",
                        "type" : "Bool"
                      },
                      {
                        "name" : "date",
                        "type" : "Date"
                      },
                      {
                        "name" : "presentedChild",
                        "type" : "State?"
                      },
                      {
                        "name" : "child",
                        "type" : "State"
                      },
                      {
                        "name" : "resource",
                        "type" : "ResourceState<String>"
                      }
                    ]
                  }
                }
              }
            }
            """
        }
    }
}
