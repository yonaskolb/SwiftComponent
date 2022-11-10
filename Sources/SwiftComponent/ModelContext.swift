import Foundation
import SwiftUI
import Combine
import CustomDump
import CasePaths

@dynamicMemberLookup
public class ModelContext<Model: ComponentModel> {

    let viewModel: ViewModel<Model>

    init(viewModel: ViewModel<Model>) {
        self.viewModel = viewModel
    }

    var state: Model.State { viewModel.state }

    public func mutate<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, _ value: Value, animation: Animation? = nil, file: StaticString = #file, line: UInt = #line) {
        viewModel.mutate(keyPath, value: value, source: .capture(file: file, line: line), animation: animation)
    }

    public func output(_ event: Model.Output, file: StaticString = #file, line: UInt = #line) {
        viewModel.output(event, source: .capture(file: file, line: line))
    }

    public subscript<Value>(dynamicMember keyPath: WritableKeyPath<Model.State, Value>) -> Value {
        get { viewModel.state[keyPath: keyPath] }
        set {
            // TODO: can't capture source location
            // https://forums.swift.org/t/add-default-parameter-support-e-g-file-to-dynamic-member-lookup/58490/2
            viewModel.mutate(keyPath, value: newValue, source: .capture(file: #file, line: #line))
        }
    }

    public func task(_ name: String, file: StaticString = #file, line: UInt = #line, _ task: () async -> Void) async {
        await viewModel.task(name, source: .capture(file: file, line: line), task)
    }

    public func task<R>(_ name: String, file: StaticString = #file, line: UInt = #line, _ task: () async throws -> R, catch catchError: (Error) -> Void) async {
        await viewModel.task(name, source: .capture(file: file, line: line), task, catch: catchError)
    }

    public func present(_ route: Model.Route, file: StaticString = #file, line: UInt = #line) {
        viewModel.present(route, source: .capture(file: file, line: line))
    }

    public func dismissRoute(file: StaticString = #file, line: UInt = #line) {
        viewModel.dismissRoute(source: .capture(file: file, line: line))
    }
}

func getResourceTaskName<State, R>(_ keyPath: KeyPath<State, Resource<R>>) -> String {
    "get \(keyPath.propertyName ?? "resource")"
}

extension ModelContext {

    @MainActor
    public func loadResource<ResourceState>(_ keyPath: WritableKeyPath<Model.State, Resource<ResourceState>>, animation: Animation? = nil, load: @MainActor () async throws -> ResourceState) async {
        mutate(keyPath.appending(path: \.isLoading), true, animation: animation)
        let name = getResourceTaskName(keyPath)
        await task(name) {
            let content = try await load()
            mutate(keyPath.appending(path: \.content), content, animation: animation)
        } catch: { error in
            mutate(keyPath.appending(path: \.error), error, animation: animation)
        }
        mutate(keyPath.appending(path: \.isLoading), false, animation: animation)
    }
}
