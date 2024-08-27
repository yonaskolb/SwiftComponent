import Foundation
import XCTest
@testable import SwiftComponent

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class MemoryTests: XCTestCase {

    @MainActor
    func testMemoryLeak() async {
        let viewModel = ViewModel<TestModel>(state: .init(child: .init(count: 2)))
            .dependency(\.continuousClock, ImmediateClock())
        await viewModel.appearAsync(first: true)
        await viewModel.sendAsync(.start)
        viewModel.disappear()
        viewModel.appear(first: true)
        viewModel.send(.start)
        viewModel.binding(\.count).wrappedValue = 2
        _ = viewModel.count

        let connectedChild = viewModel.connectedModel(TestModel.child)
        await connectedChild.appearAsync(first: true)

        let connectedOptionalChildInput = viewModel.connectedModel(TestModel.childInput, state: .init(), id: "constant")
        await connectedOptionalChildInput.appearAsync(first: true)

        let child = viewModel.scope(state: \.self) as ViewModel<TestModel>
        await child.appearAsync(first: true)
        await child.sendAsync(.start)
        child.disappear()
        child.appear(first: true)
        child.send(.start)
        child.binding(\.count).wrappedValue = 3
        _ = child.count

        try? await Task.sleep(for: .seconds(0.5))

        checkForMemoryLeak(viewModel)
        checkForMemoryLeak(viewModel.store)
        checkForMemoryLeak(viewModel.store.graph)
        checkForMemoryLeak(child)
        checkForMemoryLeak(child.store)
        checkForMemoryLeak(child.store.graph)
    }

    @ComponentModel
    fileprivate struct TestModel {

        static let child = Connection<TestModelChild> {
            $0.model.state.count = 3
        }.connect(state: \.child)

        static let childInput = Connection<TestModelChild>(output: .input(Input.child))

        struct State {
            var count = 0
            var optionalChild: TestModelChild.State?
            var child: TestModelChild.State
        }

        enum Action {
            case start
        }

        enum Input {
            case child(TestModelChild.Output)
        }

        func appear() async {
            await self.task("task") {
                state.count = 2
            }
        }

        func disappear() async {
            await self.task("task") {
                state.count = 0
            }
        }

        func handle(action: Action) async {
            switch action {
            case .start:
                try? await dependencies.continuousClock.sleep(for: .seconds(0.1))
                state.count = 1
                await self.task("task") {
                    state.count = 2
                }
            }
        }

        func handle(input: Input) async {
            switch input {
            case .child(.done): break
            }
        }
    }

    @ComponentModel
    fileprivate struct TestModelChild {
        struct State {
            var count: Int = 2
        }

        enum Output {
            case done
        }

        func appear() async {
            await self.task("task") {
                state.count = 2
            }
        }
    }
}

extension XCTestCase {
    func checkForMemoryLeak(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            if instance != nil {
                XCTFail("Instance should have been deallocated", file: file, line: line)
            }
        }
    }
}
