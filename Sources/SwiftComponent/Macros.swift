import Observation

@attached(extension, conformances: ComponentModel)
@attached(memberAttribute)
@attached(member, names: arbitrary)
public macro ComponentModel() = #externalMacro(module: "SwiftComponentMacros", type: "ComponentModelMacro")

@attached(extension, conformances: Observable, ObservableState)
@attached(member, names: named(_$id), named(_$observationRegistrar), named(_$willModify))
@attached(memberAttribute)
public macro ObservableState() = #externalMacro(module: "SwiftComponentMacros", type: "ObservableStateMacro")

@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(_))
public macro ObservationStateTracked() = #externalMacro(module: "SwiftComponentMacros", type: "ObservationStateTrackedMacro")

@attached(accessor, names: named(willSet))
public macro ObservationStateIgnored() = #externalMacro(module: "SwiftComponentMacros", type: "ObservationStateIgnoredMacro")

/// Wraps a property with ``ResourceState`` and observes it.
///
/// Use this macro instead of ``ResourceState`` when you adopt the ``ObservableState()``
/// macro, which is incompatible with property wrappers like ``ResourceState``.
@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(`$`), prefixed(_))
public macro Resource() =
  #externalMacro(module: "SwiftComponentMacros", type: "ResourceMacro")
