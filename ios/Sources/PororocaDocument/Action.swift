import PororocaExpr

/// An action dispatched from a document to its host.
public struct Action: Sendable, Equatable, Codable {
    public var name: String
    public var args: [String: Expr]
    public static let builtinNames: Set<String> = ["dismiss", "setLocal", "track", "openURL", "navigate"]
    public init(name: String, args: [String: Expr] = [:]) { self.name = name; self.args = args }
    enum CodingKeys: String, CodingKey, CaseIterable { case name, args }
    public init(from decoder: Decoder) throws { let c = try decoder.strictContainer(keyedBy: CodingKeys.self); name = try c.decode(String.self, forKey: .name); args = try c.decodeIfPresent([String: Expr].self, forKey: .args) ?? [:] }
    public func encode(to encoder: Encoder) throws { var c = encoder.container(keyedBy: CodingKeys.self); try c.encode(name, forKey: .name); if !args.isEmpty { try c.encode(args, forKey: .args) } }
}
