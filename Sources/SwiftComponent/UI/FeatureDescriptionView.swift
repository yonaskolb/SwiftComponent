import Foundation
import SwiftUI
import SwiftPreview

@_implementationOnly import Runtime

struct FeatureDescription {
    var model: ModelInfo
    var view: ViewInfo
    var feature: FeatureInfo
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

struct FeatureInfo {
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

struct FeatureDescriptionView<Feature: ComponentFeature>: View {

    var feature: FeatureDescription = try! Self.getFeatureDescription()

    var maxPillWidth = 400.0

    static func getFeatureDescription() throws -> FeatureDescription {

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
                                        String(describing: $0.type)
                                    }
                                case .struct:
                                    payloads = [payloadType.name]
                                default:
                                    payloads = [payloadType.name]
                            }
                        }
                        return .init(name: caseType.name, payloads: payloads)
                    }
                    return .enumType(cases)
                case .struct:
                    let properties: [TypeDescription.Property] = info.properties.map {
                        .init(name: $0.name, type: String(describing: $0.type))
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
            name: String(describing: Feature.Model.self),
            state: try getType(Feature.Model.State.self),
            action: try getType(Feature.Model.Action.self),
            input: try getType(Feature.Model.Input.self),
            route: try getType(Feature.Model.Route.self),
            output: try getType(Feature.Model.Output.self)
        )
        let view = ViewInfo(
            name: String(describing: Feature.ViewType.self),
            routes: []
        )
        let feature = FeatureInfo(
            name: String(describing: Feature.self),
            tests: Feature.tests.map { $0.name },
            states: Feature.states.map(\.name)
        )
        return FeatureDescription(model: model, view: view, feature: feature)
    }

    var body: some View {
        pills
    }

    var pills: some View {
        ScrollView {
            VStack {
                typeSection("State", icon: "square.text.square", feature.model.state)
                typeSection("Action", icon: "arrow.up.square", feature.model.action)
                typeSection("Input", icon: "arrow.forward.square", feature.model.input)
                typeSection("Output", icon: "arrow.backward.square", feature.model.output)
                typeSection("Route", icon: "arrow.uturn.right.square", feature.model.route)
                section("States", icon: "square.text.square") {
                    ForEach(feature.feature.states, id: \.self) { state in
                        Text(state)
                            .bold()
                    }
                    .item()
                    .frame(maxWidth: maxPillWidth)
                }
                .isUsed(!feature.feature.states.isEmpty)
                section("Tests", icon: "checkmark.square") {
                    ForEach(feature.feature.tests, id: \.self) { test in
                        Text(test)
                            .bold()
                    }
                    .item()
                    .frame(maxWidth: maxPillWidth)
                }
                .isUsed(!feature.feature.tests.isEmpty)
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
                    HStack {
                        Text(enumCase.name)
                            .bold()
                        Spacer()
                        Text(enumCase.payloads.joined(separator: ", "))
                            .bold()
                    }
                    .item()
                    .frame(maxWidth: maxPillWidth)
                }
            case .structType(let properties):
                ForEach(properties, id: \.name) { property in
                    HStack {
                        Text(property.name)
                            .bold()
                        Spacer()
                        Text(property.type)
                            .bold()
                    }
                    .item()
                    .frame(maxWidth: maxPillWidth)
                }
            case .never:
                EmptyView()
        }

    }

    func section(_ name: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: icon)
                Text(name)
                    .bold()
            }
            .font(.title2)
            .padding(.bottom, 4)
            .foregroundColor(.blue)
            content()
        }
        .padding()
//        .foregroundColor(.blue)
//        .background {
//            RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.9))
//        }
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

    func item() -> some View {
        self
            .foregroundColor(.white)
//            .foregroundColor(.primary.opacity(0.6))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 6).fill(Color.blue.opacity(0.8))
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

struct ComponentFeatureGraphView_Previews: PreviewProvider {
    static var previews: some View {
        FeatureDescriptionView<ExamplePreview>()
//            .previewDevice(.largestDevice)
    }
}
