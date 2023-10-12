import XCTest
@testable import SwiftComponent

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
@MainActor
final class TaskCancellationTests: XCTestCase {

    func test_task_cancels_old_task() async throws {
        let clock = TestClock()
        let viewModel = ViewModel<TestModel>(state: .init())
            .dependency(\.continuousClock, clock)
        
        viewModel.send(.start)
        await clock.advance(by: .seconds(1))
        viewModel.send(.stop)
        XCTAssertEqual(viewModel.count, 0)
        await clock.advance(by: .seconds(3))
        XCTAssertEqual(viewModel.count, 0)
    }

    func test_cancel_task_cancels() async throws {
        let clock = TestClock()
        let viewModel = ViewModel<TestModel>(state: .init())
            .dependency(\.continuousClock, clock)

        viewModel.send(.start)
        await clock.advance(by: .seconds(1.5))
        XCTAssertEqual(viewModel.count, 0)
        viewModel.send(.start)
        await clock.advance(by: .seconds(1.5))
        XCTAssertEqual(viewModel.count, 0)
        viewModel.send(.stop)
        await clock.advance(by: .seconds(2))
    }

    func test_cancel_tasks_cancels() async throws {
        let clock = TestClock()
        let viewModel = ViewModel<TestModel>(state: .init())
            .dependency(\.continuousClock, clock)

        viewModel.send(.start)
        await clock.advance(by: .seconds(1))
        viewModel.store.cancelTasks()
        await clock.advance(by: .seconds(3))
        XCTAssertEqual(viewModel.count, 0)
    }

    func test_disappear_cancels() async throws {
        let clock = TestClock()
        let viewModel = ViewModel<TestModel>(state: .init())
            .dependency(\.continuousClock, clock)

        viewModel.appear(first: true)
        await clock.advance(by: .seconds(1))
        XCTAssertEqual(viewModel.count, 0)
        viewModel.disappear()
        await clock.advance(by: .seconds(3))
        XCTAssertEqual(viewModel.count, 0)
    }

    @ComponentModel
    struct TestModel {

        struct State {
            var count = 0
        }

        enum Action {
            case start
            case stop
        }

        func appear() async {
            do {
                try await dependencies.continuousClock.sleep(for: .seconds(2))
                state.count = 1
            } catch {

            }
        }

        func handle(action: Action) async {
            switch action {
            case .start:
                await task("sleep", cancellable: true) {
                    do {
                        try await dependencies.continuousClock.sleep(for: .seconds(2))
                        state.count = 1
                    } catch {}
                }
            case .stop:
                cancelTask("sleep")
            }
        }
    }

}
