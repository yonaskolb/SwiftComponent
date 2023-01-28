import Foundation
import Combine
import CustomDump
import SwiftUI

public class EventStore {

    public static let shared = EventStore()
    public internal(set) var events: [ComponentEvent] = []
    public let eventPublisher = PassthroughSubject<ComponentEvent, Never>()
    #if DEBUG
    public var storeEvents = true
    #else
    public var storeEvents = false
    #endif

    func componentEvents(for path: ComponentPath, includeChildren: Bool) -> [ComponentEvent] {
        events.filter { includeChildren ? $0.componentPath.contains(path) : $0.componentPath == path }
    }

    func send(_ event: ComponentEvent) {
        if storeEvents {
            events.append(event)
        }
        eventPublisher.send(event)
    }

    func clear() {
        events = []
    }
}

public struct ComponentEvent: Identifiable {
    public var id = UUID()
    public let start: Date
    public let end: Date
    public let type: EventType
    public let depth: Int
    public let source: Source
    public var componentType: any ComponentModel.Type { componentPath.path.last! }
    public var componentName: String { componentType.baseName }
    public var componentPath: ComponentPath
    public var mutations: [Mutation]

    init(type: EventType, componentPath: ComponentPath, start: Date, end: Date, mutations: [Mutation], depth: Int, source: Source) {
        self.type = type
        self.start = start
        self.end = end
        self.mutations = mutations
        self.componentPath = componentPath
        self.depth = depth
        self.source = source
    }

    func isComponent<Model: ComponentModel>(_ type: Model.Type) -> Bool {
        componentType == type
    }

    public var duration: String {
        let seconds = end.timeIntervalSince1970 - start.timeIntervalSince1970
        if seconds < 2 {
            return Int(seconds*1000).formatted(.number) + " ms"
        } else {
            return (start ..< end).formatted(.components(style: .abbreviated))
        }
    }
}

extension ComponentEvent: CustomStringConvertible {

    public var description: String {
        "\(componentPath) \(type.title): \(type.details)"
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
        }
    }

    var color: Color {
        switch self {
            case .action:
                return .blue
            case .binding:
                return .yellow
            case .output:
                return .orange
            case .input:
                return .orange
            case .appear:
                return .purple
            case .task:
                return .green
            case .mutation:
                return .yellow
            case .route:
                return .teal
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

public struct Mutation: Identifiable {
    public let value: Any
    public let property: String
    public var valueType: String { String(describing: type(of: value)) }
    public let id = UUID()

    init<State, T>(keyPath: KeyPath<State, T>, value: T) {
        self.value = value
        self.property = keyPath.propertyName ?? "self"
    }
}
