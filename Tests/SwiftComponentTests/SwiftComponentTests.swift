import XCTest
@testable import SwiftComponent

final class SwiftComponentTests: XCTestCase {

    func testTaskCancellation() async throws {
        if #available(iOS 16, *) {

            struct Model: ComponentModel {

                struct State {
                    var count = 0
                }

                enum Action {
                    case start
                    case stop
                }

                func appear(store: Store) async {
                    do {
                        try await store.dependencies.continuousClock.sleep(for: .seconds(2))
                        store.count = 1
                    } catch {
                        store.count = -1
                    }
                }

                func handle(action: Action, store: Store) async {
                    switch action {
                        case .start:
                            await store.task("sleep", cancellable: true) {
                                do {
                                    try await store.dependencies.continuousClock.sleep(for: .seconds(2))
                                    store.count = 1
                                } catch {
                                    store.count = -1
                                }
                            }
                        case .stop:
                            store.cancelTask("sleep")
                    }
                }
            }

            let clock = TestClock()
            let viewModel = ViewModel<Model>(state: .init())
                .dependency(\.continuousClock, clock)

            // cancelTask cancels
            viewModel.send(.start)
            await clock.advance(by: .seconds(1))
            viewModel.send(.stop)
            XCTAssertEqual(viewModel.count, 0)
            await clock.advance(by: .seconds(3))
            XCTAssertEqual(viewModel.count, -1)

            // new cancellable task cancels
            viewModel.store.state.count = 0
            viewModel.send(.start)
            await clock.advance(by: .seconds(1.5))
            XCTAssertEqual(viewModel.count, 0)
            viewModel.send(.start)
            await clock.advance(by: .seconds(1.5))
            XCTAssertEqual(viewModel.count, -1)
            viewModel.send(.stop)
            await clock.advance(by: .seconds(2))

            // cancelTasks cancels
            viewModel.store.state.count = 0
            viewModel.send(.start)
            await clock.advance(by: .seconds(1))
            viewModel.store.cancelTasks()
            await clock.advance(by: .seconds(3))
            XCTAssertEqual(viewModel.count, -1)

            // disappear cancels appear
            viewModel.store.state.count = 0
            await viewModel.appear(first: true)
            await clock.advance(by: .seconds(1))
            XCTAssertEqual(viewModel.count, 0)
            await viewModel.disappear()
            await clock.advance(by: .seconds(3))
            XCTAssertEqual(viewModel.count, -1)
        }
    }
}
