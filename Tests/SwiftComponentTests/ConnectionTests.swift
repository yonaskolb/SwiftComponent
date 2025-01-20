import Foundation
import XCTest
@testable import SwiftComponent

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class ConnectionTests: XCTestCase {

    @MainActor
    func testInlineOutput() async {
        let parent = ViewModel<TestModel>(state: .init())
        let child = parent.connectedModel(\.child, state: .init(), id: "constant")

        await child.sendAsync(.sendOutput)
        try? await Task.sleep(for: .seconds(0.1)) // sending output happens via combine publisher right now so incurs a thread hop
        XCTAssertEqual(parent.state.value, "handled")
    }

    @MainActor
    func testConnectedOutput() async {
        let parent = ViewModel<TestModel>(state: .init())
        let child = parent.connectedModel(\.childConnected)

        await child.sendAsync(.sendOutput)
        try? await Task.sleep(for: .seconds(0.1)) // sending output happens via combine publisher right now so incurs a thread hop
        XCTAssertEqual(parent.state.value, "handled")
    }
    
    @MainActor
    func testDependencies() async {
        let parent = ViewModel<TestModel>(state: .init())
        let child = parent.connectedModel(\.childConnected)

        await child.sendAsync(.useDependency)
        XCTAssertEqual(child.state.number, 2)
    }
    
    @MainActor
    func testConnectedCaching() async {
        let parent = ViewModel<TestModel>(state: .init())
        
        let child1 = parent.connectedModel(\.childConnected)
        let child2 = parent.connectedModel(\.childConnected)
        XCTAssertEqual(child1.id, child2.id)
    }
    
    @MainActor
    func testStateCaching() async {
        let parent = ViewModel<TestModel>(state: .init())
        
        let child1 = parent.connectedModel(\.child, state: .init(), id: "1")
        let child2 = parent.connectedModel(\.child, state: .init(), id: "1")
        let child3 = parent.connectedModel(\.child, state: .init(), id: "2")
        XCTAssertEqual(child1.id, child2.id)
        XCTAssertNotEqual(child2.id, child3.id)
    }

    @MainActor
    func testInputOutput() async {
        let parent = ViewModel<TestModel>(state: .init())
        let child = parent.connectedModel(\.childToInput)

        await child.sendAsync(.sendOutput)
        try? await Task.sleep(for: .seconds(0.1)) // sending output happens via combine publisher right now so incurs a thread hop
        XCTAssertEqual(parent.state.value, "handled")
    }

    @MainActor
    func testActionHandler() async {
        let parent = ViewModel<TestModel>(state: .init())
        let child = parent.connectedModel(\.childAction)

        await child.sendAsync(.sendOutput)
        try? await Task.sleep(for: .seconds(0.1)) // sending output happens via combine publisher right now so incurs a thread hop
        XCTAssertEqual(parent.state.value, "action handled")
    }

    @MainActor
    func testStateBinding() async {
        let parent = ViewModel<TestModel>(state: .init())
        let child = parent.connectedModel(\.childConnected)

        await child.sendAsync(.mutateState)
        XCTAssertEqual(child.state.value, "mutated")
        XCTAssertEqual(parent.state.child.value, "mutated")
    }

    @MainActor
    func testChildAction() async {
        let parent = ViewModel<TestModel>(state: .init())
        let child = parent.connectedModel(\.childConnected)

        await parent.sendAsync(.actionToChild)
        XCTAssertEqual(child.state.value, "from parent")
        XCTAssertEqual(parent.state.child.value, "from parent")
    }
    
    @MainActor
    func testPresentedChildAction() async {
        let parent = ViewModel<TestModel>(state: .init())
        parent.state.optionalChild = .init()
        let child = parent.presentedModel(\.childPresented)

        await parent.sendAsync(.actionToOptionalChild)
        XCTAssertEqual(child.wrappedValue?.state.value, "from parent")
        XCTAssertEqual(parent.state.optionalChild?.value, "from parent")
    }
    
    @MainActor
    func testParentModelAccess() async {
        let parent = ViewModel<TestModel>(state: .init())
        let child = parent.connections.childConnected
        
        await child.sendAsync(.actionToParent)
        XCTAssertEqual(parent.state.value, "from child")
    }
    
    @MainActor
    func testChildModelAccess() async {
        let parent = ViewModel<TestModel>(state: .init())
        let child1 = parent.connections.childConnected
        parent.state.optionalChild = .init()
        let child2 = parent.presentations.childPresented
        
        await parent.sendAsync(.actionToChildren)
        
        XCTAssertEqual(child1.state.value, "from parent")
        XCTAssertEqual(child2.wrappedValue?.state.value, "from parent")
    }
    
    @MainActor
    func testSiblingModelAccess() async {
        let parent = ViewModel<TestModel>(state: .init())
        let child1 = parent.connections.childConnected
        parent.state.optionalChild = .init()
        let child2 = parent.presentations.childPresented
        
        await child2.wrappedValue?.sendAsync(.actionToSibling)
        
        XCTAssertEqual(child1.state.value, "from sibling")
    }

    @ComponentModel
    fileprivate struct TestModel {

        struct Connections {
            let child = Connection<TestModelChild> {
                $0.model.state.value = "handled"
            }
            
            let childConnected = Connection<TestModelChild> {
                $0.model.state.value = "handled"
            }
            .dependency(\.number, value: 2)
            .connect(state: \.child)
            
            let childPresented = Connection<TestModelChild> {
                $0.model.state.value = "handled"
            }
            .connect(state: \.optionalChild)
            
            let childToInput = Connection<TestModelChild>(output: .input(Input.child)).connect(state: \.child)
            
            let childAction = Connection<TestModelChild>(output: .ignore)
                .onAction {
                    $0.model.state.value = "action handled"
                }
                .connect(state: \.child)

        }

        struct State {
            var value = ""
            var optionalChild: TestModelChild.State?
            var child: TestModelChild.State = .init()
        }

        enum Action {
            case actionToChild
            case actionToOptionalChild
            case actionToChildren
        }

        enum Input {
            case child(TestModelChild.Output)
        }

        func handle(action: Action) async {
            switch action {
            case .actionToChild:
                await self.connection(\.childConnected) { model in
                    await model.handle(action: .fromParent)
                }
            case .actionToOptionalChild:
                await self.connection(\.child, state: \.optionalChild) { model in
                    await model.handle(action: .fromParent)
                }
            case .actionToChildren:
                await childModel(TestModelChild.self) { $0.state.value = "from parent" }
            }
        }

        func handle(input: Input) async {
            switch input {
            case .child(.done):
                state.value = "handled"
            }
        }
    }

    @ComponentModel
    fileprivate struct TestModelChild {

        struct State {
            var value: String = ""
            var number = 0
        }

        enum Action {
            case sendOutput
            case mutateState
            case fromParent
            case useDependency
            case actionToParent
            case actionToSibling
        }

        enum Output {
            case done
        }

        func handle(action: Action) async {
            switch action {
            case .sendOutput:
                output(.done)
            case .mutateState:
                state.value  = "mutated"
            case .fromParent:
                state.value = "from parent"
            case .useDependency:
                state.number = dependencies.number()
            case .actionToParent:
                await parentModel(TestModel.self) { $0.state.value = "from child" }
            case .actionToSibling:
                await otherModel(TestModelChild.self) { $0.state.value = "from sibling" }
            }
        }
    }
}
