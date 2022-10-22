//
//  File.swift
//  
//
//  Created by Yonas Kolb on 21/10/2022.
//

import Foundation
import CustomDump

public var viewModelEvents: [AnyEvent] = []

public func componentEvents<C: Component>(for component: C.Type) -> [Event<C>] {
    viewModelEvents.compactMap { $0.asComponentEvent() }
}

public func componentEvents(for path: ComponentPath, includeChildren: Bool) -> [AnyEvent] {
    viewModelEvents.filter { includeChildren ? $0.componentPath.contains(path) : $0.componentPath == path }
}

public struct AnyEvent: Identifiable {
    public var id: UUID
    let event: Any
    let sourceLocation: SourceLocation
    let date: Date
    let type: EventType
    let componentType: any Component.Type
    var componentName: String { String(describing: componentType) }
    var componentPath: ComponentPath

    init<C: Component>(_ event: Event<C>) {
        self.event = event
        self.componentPath = event.componentPath
        self.componentType = C.self
        self.id = event.id
        self.type = event.type.anyEvent
        self.sourceLocation = event.sourceLocation
        self.date = event.date
    }

    enum EventType {
        case binding(AnyMutation)
        case action(Any, [AnyMutation])
        case output(Any)
        case viewTask([AnyMutation])
    }

    func asComponentEvent<C: Component>() -> Event<C>? {
        event as? Event<C>
    }

    func isComponent<C: Component>(_ type: C.Type) -> Bool {
        componentType == type
    }
}

struct AnyMutation: Identifiable {
    let id: UUID
    var property: String
    var value: Any
    var valueType: String { String(describing: type(of: value)) }
}

extension Event.EventType {

    var anyEvent: AnyEvent.EventType {
        switch self {
            case .binding(let mutation):
                return .binding(mutation.anyMutation)
            case .action(let action, let mutations):
                return .action(action, mutations.map(\.anyMutation))
            case .output(let output):
                return .output(output)
            case .viewTask(let mutations):
                return .viewTask(mutations.map(\.anyMutation))
        }
    }
}

extension Mutation {

    var anyMutation: AnyMutation {
        AnyMutation(id: id, property: property, value: value)
    }
}

public struct Event<C: Component>: Identifiable {

    public var componentPath: ComponentPath
    public var id = UUID()
    public var componentName: String { String(describing: C.self)}
    public var date = Date()
    public var type: EventType
    public let sourceLocation: SourceLocation

    init(_ type: EventType, componentPath: ComponentPath, sourceLocation: SourceLocation) {
        self.type = type
        self.componentPath = componentPath
        self.sourceLocation = sourceLocation
    }

    public enum EventType {
        case viewTask([Mutation<C.State>])
        case action(C.Action, [Mutation<C.State>])
        case binding(Mutation<C.State>)
        case output(C.Output)

        public var title: String {
            switch self {
                case .action: return "Action"
                case .binding: return "Binding"
                case .output: return "Output"
                case .viewTask: return "View Task"
            }
        }

        public var details: String {
            switch self {
                case .action(let action, _):
                    return getEnumCase(action).name
                case .binding(let mutation):
                    return mutation.property
                case .output(let event):
                    return getEnumCase(event).name
                case .viewTask(let mutations):
                    return "\(mutations.count) mutation\(mutations.count == 1 ? "" : "s")"
            }
        }
    }
}
