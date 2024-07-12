import Foundation
import XCTest
@testable import SwiftComponent
import Perception

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
@MainActor
final class ObservabilityTests: XCTestCase {

    var viewModel: ViewModel<Model> = .init(state: .init())

    override func setUp() {
        viewModel = .init(state: .init())
    }

    @ComponentModel
    struct Model {

        struct State {
            var value1 = 1
            var value2 = 2
            var child: ChildModel.State?
            @Resource var resource: ResourceData?
        }
        
        struct ResourceData {
            var value1: String
            var value2: String
        }

        enum Action {
            case updateValue1
            case updateValue2
            case setChild
            case updateChild
            case reset
            case loadResource
        }

        func handle(action: Action) async {
            switch action {
            case .updateValue1: 
                state.value1 += 1
            case .updateValue2: 
                state.value2 += 1
            case .setChild: 
                state.child = .init()
            case .updateChild: 
                state.child?.value1 += 1
            case .reset:
                mutate(\.self, .init())
            case .loadResource:
                await loadResource(\.$resource) {
                    ResourceData(value1: "constant", value2: UUID().uuidString)
                }
            }
        }
    }

    @ComponentModel
    struct ChildModel {

        struct State {
            var value1 = 1
            var value2 = 2
        }

        enum Action {
            case updateValue1
            case updateValue2
        }

        func handle(action: Action) async {
            switch action {
            case .updateValue1: state.value1 += 1
            case .updateValue2: state.value2 += 1
            }
        }
    }

    func test_access_update() {

        expectUpdate {
            _ = viewModel.value1
        } update: {
            viewModel.send(.updateValue1)
        }
    }
    
    func test_reset_update() {

        expectUpdate {
            _ = viewModel.value1
        } update: {
            viewModel.send(.reset)
        }
        
        expectUpdate {
            _ = viewModel.value1
        } update: {
            viewModel.send(.updateValue1)
        }
    }

    func test_other_access_no_update() {

        expectNoUpdate {
            _ = viewModel.value2
        } update: {
            viewModel.send(.updateValue1)
        }
    }
    
    func test_no_access_no_update() {

        expectNoUpdate {
            
        } update: {
            viewModel.send(.updateValue1)
        }
    }
    
    func test_child_property_access_update() {

        viewModel = .init(state: .init(child: .init()))
        expectUpdate {
            _ = viewModel.child?.value1
        } update: {
            viewModel.send(.updateChild)
        }
    }

    func test_child_access_no_update() {

        viewModel = .init(state: .init(child: .init()))
        expectNoUpdate {
            _ = viewModel.child
        } update: {
            viewModel.send(.updateChild)
        }
    }

    func test_child_set_update() {

        expectUpdate {
            _ = viewModel.child
        } update: {
            viewModel.send(.setChild)
        }
    }

    func test_child_reset_update() {

        viewModel = .init(state: .init(child: .init()))
        expectUpdate {
            _ = viewModel.child
        } update: {
            viewModel.send(.setChild)
        }
    }
    
    func test_resource_value_update() {
        expectUpdate {
            _ = viewModel.resource
        } update: {
            viewModel.send(.loadResource)
        }
    }
    
    func test_resource_property_update() {
        expectUpdate {
            _ = viewModel.resource?.value1
        } update: {
            viewModel.send(.loadResource)
        }
    }
    
    func test_resource_wrapper_update() {
        expectUpdate {
            _ = viewModel.$resource
        } update: {
            viewModel.send(.loadResource)
        }
    }

    func expectUpdate(access: () -> Void, update: () -> Void) {
        let expectation = self.expectation(description: "expected update")
        withPerceptionTracking {
            access()
        } onChange: {
            expectation.fulfill()
        }

        update()
        
        wait(for: [expectation], timeout: 0.1)
    }

    func expectNoUpdate(access: () -> Void, update: () -> Void, file: StaticString = #file, line: UInt = #line) {
        let expectation = self.expectation(description: "expected update")
        withPerceptionTracking {
            access()
        } onChange: {
            XCTFail("Didn't expect an update", file: file, line: line)
        }
        update()
        Task {
//            try? await Task.sleep(for: .seconds(0.05))
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.2)
    }
}
