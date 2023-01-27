import Foundation
import SwiftUI
import Combine
import CustomDump
import CasePaths

@dynamicMemberLookup
public class ModelContext<Model: ComponentModel> {

    weak var viewModel: ViewModel<Model>!

    init(viewModel: ViewModel<Model>) {
        self.viewModel = viewModel
    }

    public var state: Model.State { viewModel.state }

    public func mutate<Value>(_ keyPath: WritableKeyPath<Model.State, Value>, _ value: Value, animation: Animation? = nil, file: StaticString = #file, line: UInt = #line) {
        viewModel.mutate(keyPath, value: value, animation: animation, source: .capture(file: file, line: line))
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

    public func task(_ taskID: Model.Task, file: StaticString = #file, line: UInt = #line, _ task: () async -> Void) async {
        await viewModel.task(taskID.taskName, source: .capture(file: file, line: line), task)
    }

    public func task<R>(_ taskID: Model.Task, file: StaticString = #file, line: UInt = #line, _ task: () async throws -> R, catch catchError: (Error) -> Void) async {
        await viewModel.task(taskID.taskName, source: .capture(file: file, line: line), task, catch: catchError)
    }

    public func present(_ route: Model.Route, file: StaticString = #file, line: UInt = #line) {
        viewModel.present(route, source: .capture(file: file, line: line))
    }

    public func dismissRoute(file: StaticString = #file, line: UInt = #line) {
        viewModel.dismissRoute(source: .capture(file: file, line: line))
    }
}

func getResourceTaskName<State, R>(_ keyPath: KeyPath<State, Resource<R>>) -> String {
    "load \(keyPath.propertyName ?? "resource")"
}

extension ModelContext {

    @MainActor
    public func loadResource<ResourceState>(_ keyPath: WritableKeyPath<Model.State, Resource<ResourceState>>, animation: Animation? = nil, overwriteContent: Bool = true, file: StaticString = #file, line: UInt = #line, load: @MainActor () async throws -> ResourceState) async {
        mutate(keyPath.appending(path: \.isLoading), true, animation: animation)
        let name = getResourceTaskName(keyPath)
        await viewModel.task(name, source: .capture(file: file, line: line)) {
            let content = try await load()
            mutate(keyPath.appending(path: \.content), content, animation: animation)
            if viewModel.state[keyPath: keyPath.appending(path: \.error)] != nil {
                mutate(keyPath.appending(path: \.error), nil, animation: animation)
            }
            return content
        } catch: { error in
            if overwriteContent, viewModel.state[keyPath: keyPath.appending(path: \.content)] != nil {
                mutate(keyPath.appending(path: \.content), nil, animation: animation)
            }
            mutate(keyPath.appending(path: \.error), error, animation: animation)
        }
        mutate(keyPath.appending(path: \.isLoading), false, animation: animation)
    }
}
