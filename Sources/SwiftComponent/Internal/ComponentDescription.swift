@_implementationOnly import Runtime

struct ComponentDescription: Equatable, Codable {
    var model: ModelInfo
    var component: ComponentInfo
}

extension ComponentDescription {
    init<ComponentType: Component>(type: ComponentType.Type) throws {
        func getType(_ type: Any.Type) throws -> TypeDescription {
            let info = try typeInfo(of: type)
            switch info.kind {
                case .enum:
                    let cases: [TypeDescription.Case] = try info.cases.map { caseType in
                        var payloads: [String] = []
                        if let payload = caseType.payloadType {
                            let payloadType = try typeInfo(of: payload)
                            switch payloadType.kind {
                                case .tuple:
                                    payloads = payloadType.properties
                                    .map {
                                        String(describing: $0.type).sanitizedType
                                    }
                                case .struct:
                                    payloads = [payloadType.name.sanitizedType]
                                default:
                                    payloads = [payloadType.name.sanitizedType]
                            }
                        }
                        return .init(name: caseType.name, payloads: payloads)
                    }
                    return .enumType(cases)
                case .struct:
                    let properties: [TypeDescription.Property] = info.properties
                    .map {
                        var name = $0.name
                        // remove underscores added by property wrappers and macros
                        if name.hasPrefix("_") {
                            name = String(name.dropFirst())
                        }
                        return TypeDescription.Property(name: name, type: String(describing: $0.type).sanitizedType)
                    }
                    .filter { !$0.name.hasPrefix("$") } // remove $ prefixes like registrationRegistrar
                    return .structType(properties)
                case .never:
                    return .never
                default:
                    return .structType(try info.properties.map {
                        .init(name: $0.name, type: try typeInfo(of: $0.type).name)
                    })
            }
        }
        let model = ModelInfo(
            name: String(describing: ComponentType.Model.self),
            connections: try getType(ComponentType.Model.Connections.self),
            state: try getType(ComponentType.Model.State.self),
            action: try getType(ComponentType.Model.Action.self),
            input: try getType(ComponentType.Model.Input.self),
            route: try getType(ComponentType.Model.Route.self),
            output: try getType(ComponentType.Model.Output.self)
        )
        let component = ComponentInfo(
            name: String(describing: ComponentType.self),
            tests: ComponentType.tests.map { $0.testName },
            states: ComponentType.snapshots.map(\.name)
        )
        self.init(model: model, component: component)
    }
}

struct ModelInfo: Equatable, Codable {
    var name: String
    var connections: TypeDescription
    var state: TypeDescription
    var action: TypeDescription
    var input: TypeDescription
    var route: TypeDescription
    var output: TypeDescription
}

struct ViewInfo: Equatable, Codable {
    var name: String
    var routes: [String]
}

struct ComponentInfo: Equatable, Codable {
    var name: String
    var tests: [String]
    var states: [String]
}

enum TypeDescription: Equatable, Codable {
    case enumType([Case])
    case structType([Property])
    case never

    var isNever: Bool {
        switch self {
            case .never: return true
            case .structType(let properties): return properties.isEmpty
            case .enumType(let cases): return cases.isEmpty
        }
    }

    struct Property: Equatable, Codable {
        var name: String
        var type: String
    }

    struct Case: Equatable, Codable {
        var name: String
        var payloads: [String]
    }
}


fileprivate extension String {
    var sanitizedType: String {
        self
            .replaceType("Optional", replacement: "$1?")
            .replaceType("ModelConnection", regex: "ModelConnection<(.*), (.*)>", replacement: "$2")
            .replaceType("EmbeddedComponentConnection", regex: "EmbeddedComponentConnection<(.*), (.*)>", replacement: "$2")
            .replaceType("PresentedComponentConnection", regex: "PresentedComponentConnection<(.*), (.*)>", replacement: "$2")
            .replaceType("PresentedCaseComponentConnection", regex: "PresentedCaseComponentConnection<(.*), (.*), (.*)>", replacement: "$2")
            .replaceType("ComponentRoute", replacement: "$1")
            .replaceType("Resource", replacement: "$1")
            .replaceType("Array", replacement: "[$1]")
    }
    
    func replaceType(_ type: String, replacement: String = "$1") -> String {
        if hasPrefix("\(type)<") && hasSuffix(">") {
            return self.replacingOccurrences(of: "^\(type)<(.*)>", with: replacement, options: .regularExpression).sanitizedType
        } else {
            return self
        }
    }
    
    func replaceType(_ type: String, regex: String? = nil, replacement: String = "$1") -> String {
        if hasPrefix("\(type)<") && hasSuffix(">") {
            return self.replacingOccurrences(of: regex ?? "^\(type)<(.*)>", with: replacement, options: .regularExpression).sanitizedType
        } else {
            return self
        }
    }
}
