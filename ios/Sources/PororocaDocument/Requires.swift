import PororocaExpr

/// A supported document platform.
public enum Platform: String, Sendable, Codable, CaseIterable {
    case ios, android
    public init(from decoder: Decoder) throws { self = try decodeStringEnum(Self.self, from: decoder) }
}

/// A declared host-state value type.
public enum StateType: String, Sendable, Codable, CaseIterable {
    case string
    case optionalString = "string?"
    case bool
    case optionalBool = "bool?"
    case number
    case optionalNumber = "number?"
    case array
    public init(from decoder: Decoder) throws { self = try decodeStringEnum(Self.self, from: decoder) }
}

/// Token names required by a document.
public struct TokenRequirements: Sendable, Equatable, Codable {
    public var color: [String]
    public var space: [String]
    public var radius: [String]
    public var font: [String]
    public init(color: [String] = [], space: [String] = [], radius: [String] = [], font: [String] = []) { self.color = color; self.space = space; self.radius = radius; self.font = font }
    public var isEmpty: Bool { color.isEmpty && space.isEmpty && radius.isEmpty && font.isEmpty }
    enum CodingKeys: String, CodingKey, CaseIterable { case color, space, radius, font }
    public init(from decoder: Decoder) throws {
        let c = try decoder.strictContainer(keyedBy: CodingKeys.self); color = try c.decodeIfPresent([String].self, forKey: .color) ?? []; space = try c.decodeIfPresent([String].self, forKey: .space) ?? []; radius = try c.decodeIfPresent([String].self, forKey: .radius) ?? []; font = try c.decodeIfPresent([String].self, forKey: .font) ?? []
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self); if !color.isEmpty { try c.encode(color, forKey: .color) }; if !space.isEmpty { try c.encode(space, forKey: .space) }; if !radius.isEmpty { try c.encode(radius, forKey: .radius) }; if !font.isEmpty { try c.encode(font, forKey: .font) }
    }
}

/// Capabilities a host must supply for a document.
public struct Requires: Sendable, Equatable, Codable {
    public var runtime: String
    public var state: [String: StateType]
    public var actions: [String]
    public var slots: [String]
    public var tokens: TokenRequirements
    public var strings: [String]
    public var assets: [String]
    public init(runtime: String, state: [String: StateType] = [:], actions: [String] = [], slots: [String] = [], tokens: TokenRequirements = .init(), strings: [String] = [], assets: [String] = []) { self.runtime = runtime; self.state = state; self.actions = actions; self.slots = slots; self.tokens = tokens; self.strings = strings; self.assets = assets }
    enum CodingKeys: String, CodingKey, CaseIterable { case runtime, state, actions, slots, tokens, strings, assets }
    public init(from decoder: Decoder) throws {
        let c = try decoder.strictContainer(keyedBy: CodingKeys.self); runtime = try c.decode(String.self, forKey: .runtime); state = try c.decodeIfPresent([String: StateType].self, forKey: .state) ?? [:]; actions = try c.decodeIfPresent([String].self, forKey: .actions) ?? []; slots = try c.decodeIfPresent([String].self, forKey: .slots) ?? []; tokens = try c.decodeIfPresent(TokenRequirements.self, forKey: .tokens) ?? .init(); strings = try c.decodeIfPresent([String].self, forKey: .strings) ?? []; assets = try c.decodeIfPresent([String].self, forKey: .assets) ?? []
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self); try c.encode(runtime, forKey: .runtime); if !state.isEmpty { try c.encode(state, forKey: .state) }; if !actions.isEmpty { try c.encode(actions, forKey: .actions) }; if !slots.isEmpty { try c.encode(slots, forKey: .slots) }; if !tokens.isEmpty { try c.encode(tokens, forKey: .tokens) }; if !strings.isEmpty { try c.encode(strings, forKey: .strings) }; if !assets.isEmpty { try c.encode(assets, forKey: .assets) }
    }
}
