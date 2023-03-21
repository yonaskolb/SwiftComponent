import Foundation
import Combine
import CustomDump
import SwiftUI

public class EventStore {

    public static let shared = EventStore()
    public internal(set) var events: [Event] = []
    public let eventPublisher = PassthroughSubject<Event, Never>()
    #if DEBUG
    public var storeEvents = true
    #else
    public var storeEvents = false
    #endif

    func componentEvents(for path: ComponentPath, includeChildren: Bool) -> [Event] {
        events.filter { includeChildren ? $0.path.contains(path) : $0.path == path }
    }

    func send(_ event: Event) {
        if storeEvents {
            events.append(event)
        }
        eventPublisher.send(event)
    }

    func clear() {
        events = []
    }
}

public struct Event: Identifiable {
    public var id = UUID()
    public let storeID: UUID
    public let start: Date
    public let end: Date
    public let type: EventType
    public let depth: Int
    public let source: Source
    public var modelType: any ComponentModel.Type { path.path.last! }
    public var componentName: String { modelType.baseName }
    public var path: ComponentPath
    public var mutations: [Mutation]

    init(type: EventType, storeID: UUID, componentPath: ComponentPath, start: Date, end: Date, mutations: [Mutation], depth: Int, source: Source) {
        self.type = type
        self.storeID = storeID
        self.start = start
        self.end = end
        self.mutations = mutations
        self.path = componentPath
        self.depth = depth
        self.source = source
    }

    public var duration: TimeInterval {
        end.timeIntervalSince1970 - start.timeIntervalSince1970
    }

    public var formattedDuration: String {
        let seconds = duration
        if seconds < 2 {
            return Int(seconds*1000).formatted(.number) + " ms"
        } else {
            return (start ..< end).formatted(.components(style: .abbreviated))
        }
    }
}

extension Event: CustomStringConvertible {

    public var description: String {
        "\(path) \(type.title.lowercased()): \(type.details)"
    }
}

public enum ModelEvent<Model: ComponentModel> {

    case mutation(Mutation)
    case binding(Mutation)
    case action(Model.Action)
    case input(Model.Input)
    case output(Model.Output)
    case appear(first: Bool)
    case task(TaskResult)
    case route(Model.Route)
    case dismissRoute
}

extension Event {

    public func asModel<Model: ComponentModel>(_ model: Model.Type) -> ModelEvent<Model>? {
        guard modelType == model else { return nil }
        switch type {
            case .mutation(let mutation):
                return .mutation(mutation)
            case .binding(let mutation):
                return .mutation(mutation)
            case .action(let action):
                return .action(action as! Model.Action)
            case .input(let input):
                return .input(input as! Model.Input)
            case .output(let output):
                return .output(output as! Model.Output)
            case .appear(let first):
                return .appear(first: first)
            case .task(let result):
                return .task(result)
            case .route(let route):
                return .route(route as! Model.Route)
            case .dismissRoute:
                return .dismissRoute
        }
    }

    public func forModel<Model: ComponentModel>(_ model: Model.Type = Model.self, _ run: (ModelEvent<Model>) -> Void) {
        guard let event = self.asModel(Model.self) else { return }
        run(event)
    }
}

public enum EventType {
    case mutation(Mutation)
    case binding(Mutation)
    case action(Any)
    case input(Any)
    case output(Any)
    case appear(first: Bool)
    case task(TaskResult)
    case route(Any)
    case dismissRoute

    var type: EventSimpleType {
        switch self {
            case .mutation: return .mutation
            case .action: return .action
            case .binding: return .binding
            case .output: return .output
            case .input: return .input
            case .appear: return .appear
            case .task: return .task
            case .route: return .route
            case .dismissRoute: return .dismissRoute
        }
    }
}

extension EventType {

    public var title: String { type.title }
    var color: Color {
        switch self {
            case .task(let result):
                switch result.result {
                    case .success: return .green
                    case .failure: return .red
                }
            default: return type.color
        }
    }

    public var emoji: String {
        color.circleEmoji
    }

    public var detailsTitle: String {
        switch self {
            case .action:
                return "Action Name"
            case .binding:
                return "Path"
            case .output:
                return "Output"
            case .input:
                return "Input Name"
            case .appear:
                return ""
            case .task:
                return "Name"
            case .mutation:
                return "Path"
            case .route:
                return "Route"
            case .dismissRoute:
                return ""
        }
    }

    public var valueTitle: String {
        switch self {
            case .action:
                return "Action"
            case .binding:
                return "Value"
            case .mutation:
                return "Value"
            case .output:
                return "Output"
            case .input:
                return "Input"
            case .appear:
                return ""
            case .task(let result):
                switch result.result {
                    case .success: return "Success"
                    case .failure: return "Failure"
                }
            case .route:
                return "Destination"
            case .dismissRoute:
                return ""
        }
    }

    public var details: String {
        switch self {
            case .action(let action):
                return getEnumCase(action).name
            case .binding(let mutation):
                return mutation.property
            case .mutation(let mutation):
                return mutation.property
            case .output(let event):
                return getEnumCase(event).name
            case .input(let event):
                return getEnumCase(event).name
            case .appear:
                return ""
            case .task(let result):
                return result.name
            case .route(let route):
                return getEnumCase(route).name
            case .dismissRoute:
                return ""
        }
    }

    public var value: Any {
        switch self {
            case .action(let action):
                return action
            case .binding(let mutation):
                return mutation.value
            case .mutation(let mutation):
                return mutation.value
            case .output(let output):
                return output
            case .input(let input):
                return input
            case .appear:
                return ""
            case .task(let result):
                switch result.result {
                    case .success(let value): return value
                    case .failure(let error): return error
                }
            case .route(let route):
                return route
            case .dismissRoute:
                return ""
        }
    }
}

enum EventSimpleType: String, CaseIterable {
    case appear
    case action
    case binding
    case task
    case input
    case mutation
    case route
    case output
    case dismissRoute

    static var set: Set<EventSimpleType> { Set(allCases) }

    var title: String {
        switch self {
            case .action: return "Action"
            case .binding: return "Binding"
            case .output: return "Output"
            case .input: return "Input"
            case .appear: return "Appear"
            case .task: return "Task"
            case .mutation: return "Mutation"
            case .route: return "Route"
            case .dismissRoute: return "Dismiss Route"
        }
    }

    var color: Color {
        switch self {
            case .action:
                return .purple
            case .binding:
                return .yellow
            case .output:
                return .black
            case .input:
                return .white
            case .appear:
                return .blue
            case .task:
                return .green // changed to green or red in event
            case .mutation:
                return .yellow
            case .route, .dismissRoute:
                return .orange
        }
    }
}

extension Color {

    var circleEmoji: String {
        switch self {
            case .blue, .teal:
                return "🔵"
            case .yellow:
                return "🟡"
            case .purple:
                return "🟣"
            case .orange:
                return "🟠"
            case .green:
                return "🟢"
            case .red:
                return "🔴"
            case .black:
                return "⚫️"
            case .white:
                return "⚪️"
            case .brown:
                return "🟤"
            default:
                return "⚪️"
        }
    }
}

public struct TaskResult {
    public let name: String
    public let result: Result<Any, Error>
}

// TODO: add before and after state
// TODO: then add a typed version for the typed event
public struct Mutation: Identifiable {
    public let value: Any
    public let oldState: Any
    public let property: String
    public var valueType: String { String(describing: type(of: value)) }
    public let id = UUID()
    public var newState: Any { getNewState() }
    public var oldValue: Any { getOldValue() }
    private var getOldValue: () -> Any
    private var getNewState: () -> Any

    init<State, T>(keyPath: WritableKeyPath<State, T>, value: T, oldState: State) {
        self.oldState = oldState
        self.value = value
        self.property = keyPath.propertyName ?? "self"
        self.getOldValue = { oldState[keyPath: keyPath] }
        self.getNewState = {
            var state = oldState
            state[keyPath: keyPath] = value
            return state
        }
    }

    public var stateDiff: String? {
        CustomDump.diff(oldState, newState)
    }

    public var valueDiff: String? {
        CustomDump.diff(oldValue, value)
    }
}

