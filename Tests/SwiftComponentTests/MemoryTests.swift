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
        
        let child = viewModel.connectedModel(\.child)
        await child.appearAsync(first: true)
        await child.sendAsync(.start)
        child.send(.start)
        child.binding(\.count).wrappedValue = 3
        _ = child.count
        
        let childStateIDAndInput = viewModel.connectedModel(\.childInput, state: .init(), id: "constant")
        
        await childStateIDAndInput.disappearAsync()
        await child.disappearAsync()
        await viewModel.disappearAsync()

        try? await Task.sleep(for: .seconds(0.2))

        checkForMemoryLeak(viewModel)
        checkForMemoryLeak(viewModel.store)
        checkForMemoryLeak(viewModel.store.graph)
        checkForMemoryLeak(child)
        checkForMemoryLeak(child.store)
        checkForMemoryLeak(child.store.graph)
        checkForMemoryLeak(childStateIDAndInput)
        checkForMemoryLeak(childStateIDAndInput.store)
        checkForMemoryLeak(childStateIDAndInput.store.graph)
    }

    @ComponentModel
    fileprivate struct TestModel {

        struct Connections {
            let child = Connection<TestModelChild> {
                $0.model.state.count = 3
            }.connect(state: \.child)
            
            let childInput = Connection<TestModelChild>(output: .input(Input.child))
        }

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
            addTask("long running task") {
                func makeStream() -> AsyncStream<Int> {
                    let stream = AsyncStream.makeStream(of: Int.self)
                    stream.continuation.yield(1)
                    
                    return stream.stream
                }

                for await value in makeStream() {

                }
            }
        }

        func disappear() async {
            cancelTask("long running task")
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
        
        enum Action {
            case start
        }

        enum Output {
            case done
        }

        func appear() async {
            await self.task("task") {
                state.count = 2
            }
        }
        
        func handle(action: Action) async {
            switch action {
            case .start:
                try? await dependencies.continuousClock.sleep(for: .seconds(0.1))
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
