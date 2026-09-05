@attached(
    member,
    names: named(__PororocaState), named(__PororocaAction), named(__pororocaDocument), named(__pororocaState), named(__pororocaHandle),
    named(__pororocaHostEntry), named(__pororocaHost), named(body)
)
@attached(extension, conformances: UpdatableHost)
public macro Updatable(
    _ screen: String,
    colors: String,
    spaces: String,
    radii: String,
    strings: String
) = #externalMacro(module: "PororocaMacros", type: "UpdatableMacro")

@attached(peer)
public macro OTAState() = #externalMacro(module: "PororocaMacros", type: "OTAStateMacro")

@attached(peer)
public macro OTAAction() = #externalMacro(module: "PororocaMacros", type: "OTAActionMacro")

@MainActor
public protocol UpdatableHost {
    static var __pororocaDocument: Document { get }
    var __pororocaState: StateSnapshot { get }
}
