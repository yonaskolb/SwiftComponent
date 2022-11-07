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
    public let componentType: any ComponentModel.Type
    public var componentName: String { componentPath.path.last?.baseName ?? "" }
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

    func isComponent<C: ComponentModel>(_ type: C.Type) -> Bool {
        componentType == type
    }
}

public enum EventType {
    case mutation(Mutation)
    case binding(Mutation)
    case input(Any)
    case output(Any)
    case viewTask
    case task(TaskResult)

    var type: EventSimpleType {
        switch self {
            case .mutation: return .mutation
            case .input: return .input
            case .binding: return .binding
            case .output: return .output
            case .viewTask: return .viewTask
            case .task: return .task
        }
    }
}

enum EventSimpleType: String, CaseIterable {
    case viewTask
    case input
    case binding
    case output
    case task
    case mutation

    static var set: Set<EventSimpleType> { Set(allCases) }

    var title: String {
        switch self {
            case .input: return "Input"
            case .binding: return "Binding"
            case .output: return "Output"
            case .viewTask: return "View Task"
            case .task: return "Task"
            case .mutation: return "Mutation"
        }
    }

    var color: Color {
        switch self {
            case .input:
                return .blue
            case .binding:
                return .green
            case .output:
                return .purple
            case .viewTask:
                return .orange
            case .task:
                return .red
            case .mutation:
                return .yellow
        }
    }

    var emoji: String {
        switch self {
            case .input:
                return "🔵"
            case .binding:
                return "🟡"
            case .output:
                return "🟣"
            case .viewTask:
                return "🟠"
            case .task:
                return "🟢"
            case .mutation:
                return "🟡"
        }
    }
}

public struct TaskResult {
    public let name: String
    public let result: Result<Any, Error>
}
