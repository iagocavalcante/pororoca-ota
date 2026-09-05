import PororocaExpr

/// A complete versioned Pororoca screen document.
public struct Document: Sendable, Equatable, Codable {
    public var format: Int
    public var screen: String
    public var platform: Platform
    public var requires: Requires
    public var local: [String: Value]
    public var root: Node
    public init(format: Int = 1, screen: String, platform: Platform, requires: Requires, local: [String: Value] = [:], root: Node) { self.format = format; self.screen = screen; self.platform = platform; self.requires = requires; self.local = local; self.root = root }
    enum CodingKeys: String, CodingKey, CaseIterable { case format, screen, platform, requires, local, root }
    public init(from decoder: Decoder) throws { let c = try decoder.strictContainer(keyedBy: CodingKeys.self); format = try c.decode(Int.self, forKey: .format); screen = try c.decode(String.self, forKey: .screen); platform = try c.decode(Platform.self, forKey: .platform); requires = try c.decode(Requires.self, forKey: .requires); local = try c.decodeIfPresent([String: Value].self, forKey: .local) ?? [:]; root = try c.decode(Node.self, forKey: .root) }
    public func encode(to encoder: Encoder) throws { var c = encoder.container(keyedBy: CodingKeys.self); try c.encode(format, forKey: .format); try c.encode(screen, forKey: .screen); try c.encode(platform, forKey: .platform); try c.encode(requires, forKey: .requires); if !local.isEmpty { try c.encode(local, forKey: .local) }; try c.encode(root, forKey: .root) }
}
