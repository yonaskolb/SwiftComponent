import Foundation
import XCTest
@testable import SwiftComponent

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class ConnectionTests: XCTestCase {

    @MainActor
    func testConnectionInlineOutput() async {
        let parent = ViewModel<TestModel>(state: .init())
        let child = parent.connect(to: \.child, state: .keyPath(\.child))

        await child.sendAsync(.sendOutput)
        try? await Task.sleep(for: .seconds(0.1)) // sending output happens via combine publisher right now so incurs a thread hop
        XCTAssertEqual(parent.state.value, "handled")
    }

    @MainActor
    func testInputOutput() async {
        let parent = ViewModel<TestModel>(state: .init())
        let child = parent.connect(to: \.childToInput, state: .keyPath(\.child))

        await child.sendAsync(.sendOutput)
        try? await Task.sleep(for: .seconds(0.1)) // sending output happens via combine publisher right now so incurs a thread hop
        XCTAssertEqual(parent.state.value, "handled")
    }

    @MainActor
    func testActionHandler() async {
        let parent = ViewModel<TestModel>(state: .init())
        let child = parent.connect(to: \.childAction, state: .keyPath(\.child))

        await child.sendAsync(.sendOutput)
        try? await Task.sleep(for: .seconds(0.1)) // sending output happens via combine publisher right now so incurs a thread hop
        XCTAssertEqual(parent.state.value, "action handled")
    }

    @MainActor
    func testBinding() async {
        let parent = ViewModel<TestModel>(state: .init())
        let child = parent.connect(to: \.child, state: .keyPath(\.child))

        await child.sendAsync(.mutateState)
        XCTAssertEqual(child.state.value, "mutated")
        XCTAssertEqual(parent.state.child.value, "mutated")
    }

    @MainActor
    func testOptionalBinding() async {
        let parent = ViewModel<TestModel>(state: .init())
        let child = parent.connect(to: \.child, state: .optionalKeyPath(\.optionalChild, fallback: .init(value: "parent")))

        await child.sendAsync(.mutateState)
        XCTAssertEqual(child.state.value, "mutated")
        XCTAssertEqual(parent.state.optionalChild?.value, "mutated")
    }

    @MainActor
    func testChildAction() async {
        let parent = ViewModel<TestModel>(state: .init())
        let child = parent.connect(to: \.child, state: .keyPath(\.child))

        await parent.sendAsync(.actionToChild)
        XCTAssertEqual(child.state.value, "from parent")
        XCTAssertEqual(parent.state.child.value, "from parent")
    }

    @MainActor
    func testOptionalChildAction() async {
        let parent = ViewModel<TestModel>(state: .init())
        let child = parent.connect(to: \.child, state: .optionalKeyPath(\.optionalChild, fallback: .init(value: "parent")))

        await parent.sendAsync(.actionToOptionalChild)
        XCTAssertEqual(child.state.value, "from parent")
        XCTAssertEqual(parent.state.optionalChild?.value, "from parent")
    }

    @ComponentModel
    fileprivate struct TestModel {

        let child = Connection<TestModelChild> {
            $0.model.state.value = "handled"
        }

        let childToInput = Connection<TestModelChild>(output: .input(Input.child))

        let childAction = Connection<TestModelChild>(output: .ignore)
            .onAction {
                $0.model.state.value = "action handled"
            }

        struct State {
            var value = ""
//            @Presented(\.child)
            var optionalChild: TestModelChild.State?
//            @Connected(\.child)
            var child: TestModelChild.State = .init()
        }

        enum Action {
            case actionToChild
            case actionToOptionalChild
        }

        enum Input {
            case child(TestModelChild.Output)
        }

        func handle(action: Action) async {
            switch action {
            case .actionToChild:
                await connection(\.child, state: .keyPath(\.child)).handle(action: .fromParent)
            case .actionToOptionalChild:
                state.optionalChild = .init()

                if let child = state.optionalChild {
                    await connection(\.child, state: .optionalKeyPath(\.optionalChild, fallback: child)).handle(action: .fromParent)
                }
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
        }

        enum Action {
            case sendOutput
            case mutateState
            case fromParent
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
            }
        }
    }
}
