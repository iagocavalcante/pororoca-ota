import PororocaDocument
import PororocaExpr

public typealias ActionHandler = @MainActor (_ name: String, _ args: [String: Value]) -> Void

@MainActor
public struct ScreenHost {
    public var capabilities: HostCapabilities
    public var tokens: any TokenResolver
    public var localizer: any Localizer
    public var slots: any SlotRegistry

    public init(
        capabilities: HostCapabilities,
        tokens: any TokenResolver,
        localizer: any Localizer,
        slots: any SlotRegistry = EmptySlotRegistry()
    ) {
        self.capabilities = capabilities
        self.tokens = tokens
        self.localizer = localizer
        self.slots = slots
    }

    func strings(required names: [String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: names.map { ($0, localizer.string(for: $0)) })
    }
}
