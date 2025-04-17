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

    func test_cancel_task_tracks_cancellation() async throws {
        let viewModel = ViewModel<TestModel>(state: .init())
            .dependency(\.continuousClock, ImmediateClock())

        await viewModel.sendAsync(.addLongRunningTask)
        await viewModel.sendAsync(.start)
        XCTAssertEqual(viewModel.store.cancelledTasks, [])
        await viewModel.sendAsync(.stop)
        await viewModel.sendAsync(.cancelLongRunningTask)
        XCTAssertEqual(viewModel.store.cancelledTasks, [TestModel.Task.sleep.rawValue, TestModel.Task.longRunningTask.rawValue])
        await viewModel.sendAsync(.start)
        await viewModel.sendAsync(.addLongRunningTask)
        XCTAssertEqual(viewModel.store.cancelledTasks, [])
        await viewModel.sendAsync(.cancelLongRunningTask)
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
        await clock.advance(by: .seconds(6))
        XCTAssertEqual(viewModel.count, 0)
    }

    func test_addTask_cancels() async throws {
        let clock = TestClock()
        let viewModel = ViewModel<TestModel>(state: .init())
            .dependency(\.continuousClock, clock)

        viewModel.send(.addLongRunningTask)
        await clock.advance(by: .seconds(1.5))
        XCTAssertEqual(viewModel.count, 1)
        viewModel.send(.cancelLongRunningTask)
        await clock.advance(by: .seconds(2))
        XCTAssertEqual(viewModel.count, 1)
        await clock.advance(by: .seconds(2))
    }

    @ComponentModel
    struct TestModel {

        struct State {
            var count = 0
        }

        enum Task: String, ModelTask {
            case sleep
            case longRunningTask
        }

        enum Action {
            case start
            case stop
            case addLongRunningTask
            case cancelLongRunningTask
        }

        func appear() async {
            do {
                try await dependencies.continuousClock.sleep(for: .seconds(2))
                state.count = 1
                await task(.sleep) {
                    do {
                        try await dependencies.continuousClock.sleep(for: .seconds(3))
                        state.count = 2
                    } catch {}
                }
            } catch {

            }
        }

        func handle(action: Action) async {
            switch action {
            case .start:
                await task(.sleep, cancellable: true) {
                    do {
                        try await dependencies.continuousClock.sleep(for: .seconds(2))
                        state.count = 1
                    } catch {}
                }
            case .stop:
                cancelTask(.sleep)
            case .addLongRunningTask:
                addTask(.longRunningTask) {
                    func makeStream() -> AsyncStream<Int> {
                        let stream = AsyncStream.makeStream(of: Int.self)
                        stream.continuation.yield(1)

                        return stream.stream
                    }

                    for await value in makeStream() {
                        state.count +=  value
                    }
                }
            case .cancelLongRunningTask:
                cancelTask(.longRunningTask)
            }
        }
    }

}
