@attached(extension, conformances: ComponentModel)
@attached(memberAttribute)
@attached(member, names: arbitrary)
public macro ComponentModel() = #externalMacro(module: "SwiftComponentMacros", type: "ComponentModelMacro")
