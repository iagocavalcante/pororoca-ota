/// The immutable inputs available while evaluating an expression.
public struct Environment: Sendable, Equatable, Codable {
    /// Host-provided screen state.
    public var state: [String: Value]
    /// Screen-local state.
    public var local: [String: Value]
    /// Localized strings available to `$t` expressions.
    public var strings: [String: String]
    /// The current `foreach` item, when evaluating a row.
    public var item: [String: Value]?
    /// The current `foreach` index, when evaluating a row.
    public var index: Int?

    /// Creates an expression environment.
    public init(
        state: [String: Value] = [:],
        local: [String: Value] = [:],
        strings: [String: String] = [:],
        item: [String: Value]? = nil,
        index: Int? = nil
    ) {
        self.state = state
        self.local = local
        self.strings = strings
        self.item = item
        self.index = index
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case state, local, strings, item, index
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        state = try container.decodeIfPresent([String: Value].self, forKey: .state) ?? [:]
        local = try container.decodeIfPresent([String: Value].self, forKey: .local) ?? [:]
        strings = try container.decodeIfPresent([String: String].self, forKey: .strings) ?? [:]
        item = try container.decodeIfPresent([String: Value].self, forKey: .item)
        index = try container.decodeIfPresent(Int.self, forKey: .index)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !state.isEmpty { try container.encode(state, forKey: .state) }
        if !local.isEmpty { try container.encode(local, forKey: .local) }
        if !strings.isEmpty { try container.encode(strings, forKey: .strings) }
        try container.encodeIfPresent(item, forKey: .item)
        try container.encodeIfPresent(index, forKey: .index)
    }
}
