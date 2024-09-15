import Foundation
import SwiftUI
import SwiftPreview

struct ComponentDescriptionView<ComponentType: Component>: View {

    var componentDescription: ComponentDescription = try! ComponentDescription(type: ComponentType.self)

    var maxPillWidth = 400.0

    var body: some View {
        pills
    }

    var pills: some View {
        ScrollView {
            VStack {
                typeSection("Connections", icon: "arrow.left.arrow.right.square", componentDescription.model.connections)
                typeSection("State", icon: "square.text.square", componentDescription.model.state)
                typeSection("Action", icon: "arrow.up.square", componentDescription.model.action)
                typeSection("Input", icon: "arrow.forward.square", componentDescription.model.input)
                typeSection("Output", icon: "arrow.backward.square", componentDescription.model.output)
                typeSection("Route", icon: "arrow.uturn.right.square", componentDescription.model.route)
//                section("States", icon: "square.text.square", color: .teal) {
//                    ForEach(componentDescription.component.states, id: \.self) { state in
//                        Text(state)
//                            .bold()
//                    }
//                    .item(color: .teal)
//                    .frame(maxWidth: maxPillWidth)
//                }
//                .isUsed(!componentDescription.component.states.isEmpty)
//                section("Tests", icon: "checkmark.square", color: .teal) {
//                    ForEach(componentDescription.component.tests, id: \.self) { test in
//                        Text(test)
//                            .bold()
//                    }
//                    .item(color: .teal)
//                    .frame(maxWidth: maxPillWidth)
//                }
//                .isUsed(!componentDescription.component.tests.isEmpty)
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
