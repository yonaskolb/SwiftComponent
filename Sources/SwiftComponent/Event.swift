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
    public let depth: Int
    public let sourceLocation: SourceLocation
    public let componentType: any ComponentModel.Type
    public var componentName: String { componentPath.path.last?.baseName ?? "" }
    public var componentPath: ComponentPath
    public var mutations: [Mutation]

    init(type: EventType, componentPath: ComponentPath, start: Date, end: Date, mutations: [Mutation], depth: Int, sourceLocation: SourceLocation) {
        self.type = type
        self.start = start
        self.end = end
        self.mutations = mutations
        self.componentType = componentPath.path.last!
        self.componentPath = componentPath
        self.depth = depth
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
    case appear
    case task(TaskResult)
    case present(Any)

    var type: EventSimpleType {
        switch self {
            case .mutation: return .mutation
            case .input: return .input
            case .binding: return .binding
            case .output: return .output
            case .appear: return .appear
            case .task: return .task
            case .present: return .present
        }
    }
}

enum EventSimpleType: String, CaseIterable {
    case appear
    case input
    case binding
    case task
    case mutation
    case present
    case output

    static var set: Set<EventSimpleType> { Set(allCases) }

    var title: String {
        switch self {
            case .input: return "Input"
            case .binding: return "Binding"
            case .output: return "Output"
            case .appear: return "Appear"
            case .task: return "Task"
            case .mutation: return "Mutation"
            case .present: return "Present"
        }
    }

    var color: Color {
        switch self {
            case .input:
                return .blue
            case .binding:
                return .white
            case .output:
                return .orange
            case .appear:
                return .purple
            case .task:
                return .green
            case .mutation:
                return .yellow
            case .present:
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
