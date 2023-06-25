import Foundation
import SwiftUI
import SwiftPreview

@_implementationOnly import Runtime

struct ComponentDescription {
    var model: ModelInfo
    var view: ViewInfo
    var component: ComponentInfo
}

struct ModelInfo {
    var name: String
    var state: TypeDescription
    var action: TypeDescription
    var input: TypeDescription
    var route: TypeDescription
    var output: TypeDescription
}

struct ViewInfo {
    var name: String
    var routes: [String]
}

struct ComponentInfo {
    var name: String
    var tests: [String]
    var states: [String]
}

enum TypeDescription {
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

    struct Property {
        var name: String
        var type: String
    }

    struct Case {
        var name: String
        var payloads: [String]
    }
}

struct ComponentDescriptionView<ComponentType: Component>: View {

    var componentDescription: ComponentDescription = try! Self.getComponentDescription()

    var maxPillWidth = 400.0

    static func getComponentDescription() throws -> ComponentDescription {

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
                    let properties: [TypeDescription.Property] = info.properties.map {
                        .init(name: $0.name, type: String(describing: $0.type).sanitizedType)
                    }
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
            state: try getType(ComponentType.Model.State.self),
            action: try getType(ComponentType.Model.Action.self),
            input: try getType(ComponentType.Model.Input.self),
            route: try getType(ComponentType.Model.Route.self),
            output: try getType(ComponentType.Model.Output.self)
        )
        let view = ViewInfo(
            name: String(describing: ComponentType.ViewType.self),
            routes: []
        )
        let component = ComponentInfo(
            name: String(describing: ComponentType.self),
            tests: ComponentType.tests.map { $0.testName },
            states: ComponentType.states.map(\.name)
        )
        return ComponentDescription(model: model, view: view, component: component)
    }

    var body: some View {
        pills
    }

    var pills: some View {
        ScrollView {
            VStack {
                typeSection("State", icon: "square.text.square", componentDescription.model.state)
                typeSection("Action", icon: "arrow.up.square", componentDescription.model.action)
                typeSection("Input", icon: "arrow.forward.square", componentDescription.model.input)
                typeSection("Output", icon: "arrow.backward.square", componentDescription.model.output)
                typeSection("Route", icon: "arrow.uturn.right.square", componentDescription.model.route)
                section("States", icon: "square.text.square", color: .teal) {
                    ForEach(componentDescription.component.states, id: \.self) { state in
                        Text(state)
                            .bold()
                    }
                    .item(color: .teal)
                    .frame(maxWidth: maxPillWidth)
                }
                .isUsed(!componentDescription.component.states.isEmpty)
                section("Tests", icon: "checkmark.square", color: .teal) {
                    ForEach(componentDescription.component.tests, id: \.self) { test in
                        Text(test)
                            .bold()
                    }
                    .item(color: .teal)
                    .frame(maxWidth: maxPillWidth)
                }
                .isUsed(!componentDescription.component.tests.isEmpty)
            }
            .padding(20)
        }
    }

    func typeSection(_ name: String, icon: String, _ type: TypeDescription) -> some View {
        section(name, icon: icon) {
            typeView(type)
                .frame(maxWidth: maxPillWidth)
        }
        .isUsed(!type.isNever)
    }

    @ViewBuilder
    func typeView(_ type: TypeDescription) -> some View {
        switch type {
            case .enumType(let cases):
                ForEach(cases, id: \.name) { enumCase in
                    HStack(alignment: .top) {
                        Text(enumCase.name)
                            .bold()
                        Spacer()
                        Text(enumCase.payloads.joined(separator: ", "))
                            .bold()
                            .multilineTextAlignment(.trailing)
                    }
                    .item()
                    .frame(maxWidth: maxPillWidth)
                }
            case .structType(let properties):
                ForEach(properties, id: \.name) { property in
                    HStack(alignment: .top) {
                        Text(property.name)
                            .bold()
                        Spacer()
                        Text(property.type)
                            .bold()
                            .multilineTextAlignment(.trailing)
                    }
                    .item()
                    .frame(maxWidth: maxPillWidth)
                }
            case .never:
                EmptyView()
        }

    }

    func section(_ name: String, icon: String, color: Color = .blue, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: icon)
                Text(name)
                    .bold()
            }
            .font(.title2)
            .padding(.bottom, 4)
            .foregroundColor(color)
            content()
        }
        .padding()
//        .foregroundColor(.blue)
//        .background {
//            RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.9))
//        }
    }
}

fileprivate extension String {
    var sanitizedType: String {
        if hasPrefix("Optional<") && hasSuffix(">") {
            return "\(String(self.dropFirst(9).dropLast(1)))?".sanitizedType
        }
        if hasPrefix("ComponentRoute<") && hasSuffix(">") {
            return "\(String(self.dropFirst(15).dropLast(1)))".sanitizedType
        }
        if hasPrefix("Resource<") && hasSuffix(">") {
            return "\(String(self.dropFirst(9).dropLast(1)))".sanitizedType
        }
        if hasPrefix("Array<") && hasSuffix(">") {
            return "[\(String(self.dropFirst(6).dropLast(1)))]".sanitizedType
        }
        return self
    }
}

fileprivate extension View {

    @ViewBuilder
    func isUsed(_ used: Bool) -> some View {
        if used {
            self
        }
//        self.opacity(used ? 1 : 0.2)
    }

    func item(color: Color = Color.blue.opacity(0.8)) -> some View {
        self
            .foregroundColor(.white)
//            .foregroundColor(.primary.opacity(0.6))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 6).fill(color)
            }
    }

    func graphBackground() -> some View {
        self
            .padding(20)
            .foregroundColor(.white)
            .background {
                RoundedRectangle(cornerRadius: 12).fill(Color.blue)
                RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.5))
            }
    }
}

struct ComponentDescriptionView_Previews: PreviewProvider {
    static var previews: some View {
        ComponentDescriptionView<ExampleComponent>()
//            .previewDevice(.largestDevice)
    }
}
