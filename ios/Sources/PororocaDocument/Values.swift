import PororocaExpr

/// A validated six- or eight-digit hexadecimal color.
public struct HexColor: Sendable, Hashable, Codable {
    public let rawValue: String
    public init?(_ string: String) {
        guard [7, 9].contains(string.count), string.first == "#", string.dropFirst().allSatisfy(\.isHexDigit) else { return nil }
        rawValue = string
    }
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let value = HexColor(raw) else { throw invalidValue(decoder, raw) }
        self = value
    }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}

/// A token or literal hexadecimal color.
public enum ColorValue: Sendable, Equatable, Codable {
    case token(name: String, opacity: Double?)
    case hex(HexColor)
    enum CodingKeys: String, CodingKey, CaseIterable { case token = "$color", opacity, hex }
    public init(from decoder: Decoder) throws {
        let c = try decoder.strictContainer(keyedBy: CodingKeys.self)
        if c.contains(.token) {
            guard !c.contains(.hex) else { throw invalidValue(decoder, "color has multiple representations") }
            self = .token(name: try c.decode(String.self, forKey: .token), opacity: try c.decodeIfPresent(Double.self, forKey: .opacity))
        } else if c.contains(.hex) {
            guard !c.contains(.opacity) else { throw invalidValue(decoder, "opacity is only valid with $color") }
            self = .hex(try c.decode(HexColor.self, forKey: .hex))
        } else { throw invalidValue(decoder, "missing $color or hex") }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .token(name, opacity): try c.encode(name, forKey: .token); try c.encodeIfPresent(opacity, forKey: .opacity)
        case let .hex(value): try c.encode(value, forKey: .hex)
        }
    }
}

/// A named unit point for gradients and alignment.
public enum UnitPointName: String, Sendable, Codable, CaseIterable {
    case top, bottom, leading, trailing, topLeading, topTrailing, bottomLeading, bottomTrailing, center
    public init(from decoder: Decoder) throws { self = try decodeStringEnum(Self.self, from: decoder) }
}

/// A linear gradient payload.
public struct LinearGradientValue: Sendable, Equatable, Codable {
    public var colors: [ColorValue]
    public var start: UnitPointName
    public var end: UnitPointName
    public init(colors: [ColorValue], start: UnitPointName, end: UnitPointName) { self.colors = colors; self.start = start; self.end = end }
    enum CodingKeys: String, CodingKey, CaseIterable { case colors, start, end }
    public init(from decoder: Decoder) throws {
        let c = try decoder.strictContainer(keyedBy: CodingKeys.self); colors = try c.decode([ColorValue].self, forKey: .colors)
        guard !colors.isEmpty else { throw invalidValue(decoder, "gradient colors must not be empty") }
        start = try c.decode(UnitPointName.self, forKey: .start); end = try c.decode(UnitPointName.self, forKey: .end)
    }
}

/// A supported gradient.
public enum GradientValue: Sendable, Equatable, Codable {
    case linear(LinearGradientValue)
    enum CodingKeys: String, CodingKey, CaseIterable { case linear }
    public init(from decoder: Decoder) throws { let c = try decoder.strictContainer(keyedBy: CodingKeys.self); self = .linear(try c.decode(LinearGradientValue.self, forKey: .linear)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.container(keyedBy: CodingKeys.self); if case let .linear(value) = self { try c.encode(value, forKey: .linear) } }
}

/// A color or gradient paint value.
public enum Paint: Sendable, Equatable, Codable {
    case color(ColorValue)
    case gradient(GradientValue)
    public init(from decoder: Decoder) throws {
        let raw = try decoder.container(keyedBy: AnyCodingKey.self)
        let keys = Set(raw.allKeys.map(\.stringValue))
        if keys.contains("linear") { self = .gradient(try GradientValue(from: decoder)) }
        else { self = .color(try ColorValue(from: decoder)) }
    }
    public func encode(to encoder: Encoder) throws { switch self { case let .color(v): try v.encode(to: encoder); case let .gradient(v): try v.encode(to: encoder) } }
}

/// A fixed point dimension or named space token.
public enum Dim: Sendable, Equatable, Codable {
    case points(Double)
    case token(String)
    enum CodingKeys: String, CodingKey, CaseIterable { case token = "$space" }
    public init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(Double.self) { self = .points(value); return }
        let c = try decoder.strictContainer(keyedBy: CodingKeys.self); self = .token(try c.decode(String.self, forKey: .token))
    }
    public func encode(to encoder: Encoder) throws { switch self { case let .points(v): var c = encoder.singleValueContainer(); try c.encode(v); case let .token(v): var c = encoder.container(keyedBy: CodingKeys.self); try c.encode(v, forKey: .token) } }
}

/// A fixed corner radius or named radius token.
public enum Radius: Sendable, Equatable, Codable {
    case points(Double)
    case token(String)
    enum CodingKeys: String, CodingKey, CaseIterable { case token = "$radius" }
    public init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(Double.self) { self = .points(value); return }
        let c = try decoder.strictContainer(keyedBy: CodingKeys.self); self = .token(try c.decode(String.self, forKey: .token))
    }
    public func encode(to encoder: Encoder) throws { switch self { case let .points(v): var c = encoder.singleValueContainer(); try c.encode(v); case let .token(v): var c = encoder.container(keyedBy: CodingKeys.self); try c.encode(v, forKey: .token) } }
}

/// A supported system font weight.
public enum FontWeight: String, Sendable, Codable, CaseIterable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
    public init(from decoder: Decoder) throws { self = try decodeStringEnum(Self.self, from: decoder) }
}
/// A supported system font design.
public enum FontDesign: String, Sendable, Codable, CaseIterable {
    case `default`, serif, rounded, monospaced
    public init(from decoder: Decoder) throws { self = try decodeStringEnum(Self.self, from: decoder) }
}
/// A system font description.
public struct SystemFont: Sendable, Equatable, Codable {
    public var size: Double
    public var weight: FontWeight?
    public var design: FontDesign?
    public init(size: Double, weight: FontWeight? = nil, design: FontDesign? = nil) { self.size = size; self.weight = weight; self.design = design }
    enum CodingKeys: String, CodingKey, CaseIterable { case size, weight, design }
    public init(from decoder: Decoder) throws { let c = try decoder.strictContainer(keyedBy: CodingKeys.self); size = try c.decode(Double.self, forKey: .size); weight = try c.decodeIfPresent(FontWeight.self, forKey: .weight); design = try c.decodeIfPresent(FontDesign.self, forKey: .design) }
}
/// A token or system font.
public enum FontValue: Sendable, Equatable, Codable {
    case token(String)
    case system(SystemFont)
    enum CodingKeys: String, CodingKey, CaseIterable { case token = "$font", system }
    public init(from decoder: Decoder) throws {
        let c = try decoder.strictContainer(keyedBy: CodingKeys.self)
        if c.contains(.token) { guard !c.contains(.system) else { throw invalidValue(decoder, "font has multiple representations") }; self = .token(try c.decode(String.self, forKey: .token)) }
        else if c.contains(.system) { self = .system(try c.decode(SystemFont.self, forKey: .system)) }
        else { throw invalidValue(decoder, "missing $font or system") }
    }
    public func encode(to encoder: Encoder) throws { var c = encoder.container(keyedBy: CodingKeys.self); switch self { case let .token(v): try c.encode(v, forKey: .token); case let .system(v): try c.encode(v, forKey: .system) } }
}

/// A literal, localized, or expression-derived string.
public enum Str: Sendable, Equatable, Codable {
    case literal(String)
    case localized(String)
    case expr(Expr)
    enum CodingKeys: String, CodingKey, CaseIterable { case localized = "$t", expr }
    public init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) { self = .literal(value); return }
        let c = try decoder.strictContainer(keyedBy: CodingKeys.self)
        if c.contains(.localized) { guard !c.contains(.expr) else { throw invalidValue(decoder, "string has multiple representations") }; self = .localized(try c.decode(String.self, forKey: .localized)) }
        else if c.contains(.expr) { self = .expr(try c.decode(Expr.self, forKey: .expr)) }
        else { throw invalidValue(decoder, "missing $t or expr") }
    }
    public func encode(to encoder: Encoder) throws { switch self { case let .literal(v): var c = encoder.singleValueContainer(); try c.encode(v); case let .localized(v): var c = encoder.container(keyedBy: CodingKeys.self); try c.encode(v, forKey: .localized); case let .expr(v): var c = encoder.container(keyedBy: CodingKeys.self); try c.encode(v, forKey: .expr) } }
}

/// A numeric frame dimension or unbounded infinity.
public enum FrameDimension: Sendable, Equatable, Codable {
    case points(Double)
    case infinity
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let value = try? c.decode(Double.self) { self = .points(value); return }
        let raw = try c.decode(String.self); guard raw == "infinity" else { throw invalidValue(decoder, raw) }; self = .infinity
    }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); switch self { case let .points(v): try c.encode(v); case .infinity: try c.encode("infinity") } }
}

/// A set of layout edges.
public enum Edges: String, Sendable, Codable, CaseIterable {
    case all, horizontal, vertical, top, bottom, leading, trailing
    public var edgeSet: Set<Edge> { switch self { case .all: Set(Edge.allCases); case .horizontal: [.leading, .trailing]; case .vertical: [.top, .bottom]; case .top: [.top]; case .bottom: [.bottom]; case .leading: [.leading]; case .trailing: [.trailing] } }
    public func overlaps(_ other: Edges) -> Bool { !edgeSet.isDisjoint(with: other.edgeSet) }
    public init(from decoder: Decoder) throws { self = try decodeStringEnum(Self.self, from: decoder) }
}
/// One concrete layout edge.
public enum Edge: String, Sendable, Hashable, CaseIterable { case top, bottom, leading, trailing }
/// Horizontal stack alignment.
public enum HorizontalAlignment: String, Sendable, Codable, CaseIterable { case leading, center, trailing; public init(from decoder: Decoder) throws { self = try decodeStringEnum(Self.self, from: decoder) } }
/// Vertical stack alignment.
public enum VerticalAlignment: String, Sendable, Codable, CaseIterable { case top, center, bottom, firstTextBaseline, lastTextBaseline; public init(from decoder: Decoder) throws { self = try decodeStringEnum(Self.self, from: decoder) } }
/// Two-dimensional alignment.
public enum Alignment: String, Sendable, Codable, CaseIterable { case center, top, bottom, leading, trailing, topLeading, topTrailing, bottomLeading, bottomTrailing; public init(from decoder: Decoder) throws { self = try decodeStringEnum(Self.self, from: decoder) } }
/// Text alignment.
public enum TextAlignment: String, Sendable, Codable, CaseIterable { case leading, center, trailing; public init(from decoder: Decoder) throws { self = try decodeStringEnum(Self.self, from: decoder) } }
/// Scroll axis.
public enum Axis: String, Sendable, Codable, CaseIterable { case vertical, horizontal; public init(from decoder: Decoder) throws { self = try decodeStringEnum(Self.self, from: decoder) } }
/// Image content mode.
public enum ContentMode: String, Sendable, Codable, CaseIterable { case fit, fill; public init(from decoder: Decoder) throws { self = try decodeStringEnum(Self.self, from: decoder) } }
/// Shape primitive kind.
public enum ShapeKind: String, Sendable, Codable, CaseIterable { case rect, rounded, capsule, circle; public init(from decoder: Decoder) throws { self = try decodeStringEnum(Self.self, from: decoder) } }
/// Semantic button role.
public enum ButtonRole: String, Sendable, Codable, CaseIterable { case destructive, cancel; public init(from decoder: Decoder) throws { self = try decodeStringEnum(Self.self, from: decoder) } }
/// Modifier clipping shape.
public enum ClipShape: String, Sendable, Codable, CaseIterable { case capsule, circle; public init(from decoder: Decoder) throws { self = try decodeStringEnum(Self.self, from: decoder) } }
/// Rounded corner rendering style.
public enum CornerStyle: String, Sendable, Codable, CaseIterable { case continuous, circular; public init(from decoder: Decoder) throws { self = try decodeStringEnum(Self.self, from: decoder) } }

/// A bundled or content-addressed image source.
public enum ImageSource: Sendable, Equatable, Codable {
    case bundled(String)
    case asset(String)
    enum CodingKeys: String, CodingKey, CaseIterable { case bundled = "$bundled", asset = "$asset" }
    public init(from decoder: Decoder) throws { let c = try decoder.strictContainer(keyedBy: CodingKeys.self); if c.contains(.bundled) { guard !c.contains(.asset) else { throw invalidValue(decoder, "image has multiple sources") }; self = .bundled(try c.decode(String.self, forKey: .bundled)) } else if c.contains(.asset) { self = .asset(try c.decode(String.self, forKey: .asset)) } else { throw invalidValue(decoder, "missing image source") } }
    public func encode(to encoder: Encoder) throws { var c = encoder.container(keyedBy: CodingKeys.self); switch self { case let .bundled(v): try c.encode(v, forKey: .bundled); case let .asset(v): try c.encode(v, forKey: .asset) } }
}

/// A slot property supported by the runtime bridge.
public enum SlotProp: Sendable, Equatable, Codable {
    case string(Str)
    case number(Double)
    case bool(Bool)
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let value = try? c.decode(Bool.self) { self = .bool(value) }
        else if let value = try? c.decode(Double.self) { self = .number(value) }
        else { self = .string(try Str(from: decoder)) }
    }
    public func encode(to encoder: Encoder) throws { switch self { case let .string(v): try v.encode(to: encoder); case let .number(v): var c = encoder.singleValueContainer(); try c.encode(v); case let .bool(v): var c = encoder.singleValueContainer(); try c.encode(v) } }
}
