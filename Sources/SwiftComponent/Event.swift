//
//  File.swift
//  
//
//  Created by Yonas Kolb on 21/10/2022.
//

import Foundation
import CustomDump
import SwiftUI

var viewModelEvents: [ComponentEvent] = []

public func componentEvents(for path: ComponentPath, includeChildren: Bool) -> [ComponentEvent] {
    viewModelEvents.filter { includeChildren ? $0.componentPath.contains(path) : $0.componentPath == path }
}

public struct ComponentEvent: Identifiable {
    public var id = UUID()
    public let start: Date
    public let end: Date
    public let type: EventType
    public let sourceLocation: SourceLocation
    public let componentType: any Component.Type
    public var componentName: String { componentPath.path.last?.name ?? "" }
    public var componentPath: ComponentPath
    public var mutations: [Mutation]

    init(type: EventType, componentPath: ComponentPath, start: Date, end: Date, mutations: [Mutation], sourceLocation: SourceLocation) {
        self.type = type
        self.start = start
        self.end = end
        self.mutations = mutations
        self.componentType = componentPath.path.last!
        self.componentPath = componentPath
        self.sourceLocation = sourceLocation
    }

    func isComponent<C: Component>(_ type: C.Type) -> Bool {
        componentType == type
    }
}

public enum EventType {
    case binding(Mutation)
    case action(Any)
    case output(Any)
    case viewTask
    case task(TaskResult)

    var type: EventSimpleType {
        switch self {
            case .action: return .action
            case .binding: return .binding
            case .output: return .output
            case .viewTask: return .viewTask
            case .task: return .task
        }
    }
}

enum EventSimpleType: String, CaseIterable {
    case viewTask
    case action
    case binding
    case output
    case task

    static var set: Set<EventSimpleType> { Set(allCases) }

    var title: String {
        switch self {
            case .action: return "Action"
            case .binding: return "Binding"
            case .output: return "Output"
            case .viewTask: return "View Task"
            case .task: return "Task"
        }
    }

    var color: Color {
        switch self {
            case .action:
                return .blue
            case .binding:
                return .green
            case .output:
                return .purple
            case .viewTask:
                return .orange
            case .task:
                return .red
        }
    }

    var emoji: String {
        switch self {
            case .action:
                return "🔵"
            case .binding:
                return "🟡"
            case .output:
                return "🟣"
            case .viewTask:
                return "🟠"
            case .task:
                return "🟢"
        }
    }
}

public struct TaskResult {
    public let name: String
    public let result: Result<Any, Error>
}
