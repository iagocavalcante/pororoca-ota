/// The data-only expression language used by Pororoca documents.
public indirect enum Expr: Sendable, Equatable, Codable {
    case literal(Value)
    case state(String)
    case local(String)
    case item(String)
    case index
    case localized(String)
    case eq(Expr, Expr)
    case ne(Expr, Expr)
    case lt(Expr, Expr)
    case le(Expr, Expr)
    case gt(Expr, Expr)
    case ge(Expr, Expr)
    case and([Expr])
    case or([Expr])
    case not(Expr)
    case coalesce([Expr])
    case concat([Expr])
    case fmt(Format)
    case `case`(on: Expr, cases: [String: Expr], default: Expr?)
    case count(Expr)
    case empty(Expr)

    public init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if single.decodeNil() { self = .literal(.null); return }
        if let value = try? single.decode(Bool.self) { self = .literal(.bool(value)); return }
        if let value = try? single.decode(Double.self) { self = .literal(.number(value)); return }
        if let value = try? single.decode(String.self) { self = .literal(.string(value)); return }
        if var array = try? decoder.unkeyedContainer() {
            var values: [Value] = []
            while !array.isAtEnd { values.append(try array.decode(Value.self)) }
            self = .literal(.array(values))
            return
        }

        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        let keys = container.allKeys.map(\.stringValue).sorted()
        guard keys.count == 1, let name = keys.first else {
            throw ExprCodecError(code: .unknownOperator, path: JSONPath(codingPath: decoder.codingPath), detail: "expected one operator key, found \(keys)")
        }
        let key = AnyCodingKey(stringValue: name)
        let malformed: (String) -> ExprCodecError = {
            ExprCodecError(code: .malformed, path: JSONPath(codingPath: decoder.codingPath), detail: $0)
        }

        switch name {
        case "state": self = .state(try container.decode(String.self, forKey: key))
        case "local": self = .local(try container.decode(String.self, forKey: key))
        case "item": self = .item(try container.decode(String.self, forKey: key))
        case "$t": self = .localized(try container.decode(String.self, forKey: key))
        case "index":
            guard try container.decode(Bool.self, forKey: key) else { throw malformed("index must be true") }
            self = .index
        case "==": self = try Self.binary({ .eq($0, $1) }, container: container, key: key, error: malformed)
        case "!=": self = try Self.binary({ .ne($0, $1) }, container: container, key: key, error: malformed)
        case "<": self = try Self.binary({ .lt($0, $1) }, container: container, key: key, error: malformed)
        case "<=": self = try Self.binary({ .le($0, $1) }, container: container, key: key, error: malformed)
        case ">": self = try Self.binary({ .gt($0, $1) }, container: container, key: key, error: malformed)
        case ">=": self = try Self.binary({ .ge($0, $1) }, container: container, key: key, error: malformed)
        case "&&": self = .and(try Self.operands(container, key, minimum: 1, error: malformed))
        case "||": self = .or(try Self.operands(container, key, minimum: 1, error: malformed))
        case "??": self = .coalesce(try Self.operands(container, key, minimum: 2, error: malformed))
        case "concat": self = .concat(try Self.operands(container, key, minimum: 1, error: malformed))
        case "!": self = .not(try Self.unary(container, key, error: malformed))
        case "count": self = .count(try Self.unary(container, key, error: malformed))
        case "empty": self = .empty(try Self.unary(container, key, error: malformed))
        case "fmt": self = .fmt(try container.decode(Format.self, forKey: key))
        case "case":
            let payload = try container.decode(CasePayload.self, forKey: key)
            self = .case(on: payload.on, cases: payload.cases, default: payload.default)
        default:
            throw ExprCodecError(code: .unknownOperator, path: JSONPath(codingPath: decoder.codingPath), detail: name)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .literal(value): try value.encode(to: encoder)
        default:
            var container = encoder.container(keyedBy: AnyCodingKey.self)
            func key(_ value: String) -> AnyCodingKey { AnyCodingKey(stringValue: value) }
            switch self {
            case let .state(value): try container.encode(value, forKey: key("state"))
            case let .local(value): try container.encode(value, forKey: key("local"))
            case let .item(value): try container.encode(value, forKey: key("item"))
            case .index: try container.encode(true, forKey: key("index"))
            case let .localized(value): try container.encode(value, forKey: key("$t"))
            case let .eq(a, b): try container.encode([a, b], forKey: key("=="))
            case let .ne(a, b): try container.encode([a, b], forKey: key("!="))
            case let .lt(a, b): try container.encode([a, b], forKey: key("<"))
            case let .le(a, b): try container.encode([a, b], forKey: key("<="))
            case let .gt(a, b): try container.encode([a, b], forKey: key(">"))
            case let .ge(a, b): try container.encode([a, b], forKey: key(">="))
            case let .and(values): try container.encode(values, forKey: key("&&"))
            case let .or(values): try container.encode(values, forKey: key("||"))
            case let .not(value): try container.encode([value], forKey: key("!"))
            case let .coalesce(values): try container.encode(values, forKey: key("??"))
            case let .concat(values): try container.encode(values, forKey: key("concat"))
            case let .fmt(format): try container.encode(format, forKey: key("fmt"))
            case let .case(on, cases, defaultValue):
                try container.encode(CasePayload(on: on, cases: cases, default: defaultValue), forKey: key("case"))
            case let .count(value): try container.encode([value], forKey: key("count"))
            case let .empty(value): try container.encode([value], forKey: key("empty"))
            case .literal: break
            }
        }
    }

    private static func operands(
        _ container: KeyedDecodingContainer<AnyCodingKey>, _ key: AnyCodingKey,
        minimum: Int, error: (String) -> ExprCodecError
    ) throws -> [Expr] {
        let values = try container.decode([Expr].self, forKey: key)
        guard values.count >= minimum else { throw error("operator requires at least \(minimum) operand(s)") }
        return values
    }

    private static func unary(
        _ container: KeyedDecodingContainer<AnyCodingKey>, _ key: AnyCodingKey,
        error: (String) -> ExprCodecError
    ) throws -> Expr {
        let values = try container.decode([Expr].self, forKey: key)
        guard values.count == 1, let value = values.first else { throw error("operator requires exactly one operand") }
        return value
    }

    private static func binary(
        _ make: (Expr, Expr) -> Expr, container: KeyedDecodingContainer<AnyCodingKey>,
        key: AnyCodingKey, error: (String) -> ExprCodecError
    ) throws -> Expr {
        let values = try container.decode([Expr].self, forKey: key)
        guard values.count == 2 else { throw error("operator requires exactly two operands") }
        return make(values[0], values[1])
    }
}

private struct CasePayload: Sendable, Equatable, Codable {
    var on: Expr
    var cases: [String: Expr]
    var `default`: Expr?
    enum CodingKeys: String, CodingKey, CaseIterable { case on, cases, `default` }
    init(on: Expr, cases: [String: Expr], default: Expr?) { self.on = on; self.cases = cases; self.default = `default` }
    init(from decoder: Decoder) throws {
        let c = try decoder.strictContainer(keyedBy: CodingKeys.self)
        on = try c.decode(Expr.self, forKey: .on)
        cases = try c.decode([String: Expr].self, forKey: .cases)
        `default` = try c.decodeIfPresent(Expr.self, forKey: .default)
    }
}

/// A supported formatting expression.
public indirect enum Format: Sendable, Equatable, Codable {
    case number(value: Expr, NumberFormatOptions)
    case currency(value: Expr, CurrencyFormatOptions)
    case date(value: Expr, DateFormatOptions)
    case plural(value: Expr, PluralFormatOptions)

    private enum CodingKeys: String, CodingKey, CaseIterable { case kind, value, options }
    private enum Kind: String, Codable { case number, currency, date, plural }

    public init(from decoder: Decoder) throws {
        let c = try decoder.strictContainer(keyedBy: CodingKeys.self)
        let rawKind = try c.decode(String.self, forKey: .kind)
        guard let kind = Kind(rawValue: rawKind) else {
            throw ExprCodecError(code: .malformed, path: JSONPath(codingPath: decoder.codingPath).appending("kind"), detail: rawKind)
        }
        let value = try c.decode(Expr.self, forKey: .value)
        switch kind {
        case .number: self = .number(value: value, try c.decodeIfPresent(NumberFormatOptions.self, forKey: .options) ?? .init())
        case .currency: self = .currency(value: value, try c.decode(CurrencyFormatOptions.self, forKey: .options))
        case .date: self = .date(value: value, try c.decodeIfPresent(DateFormatOptions.self, forKey: .options) ?? .init())
        case .plural: self = .plural(value: value, try c.decodeIfPresent(PluralFormatOptions.self, forKey: .options) ?? .init())
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .number(value, options):
            try c.encode(Kind.number, forKey: .kind); try c.encode(value, forKey: .value)
            if !options.isEmpty { try c.encode(options, forKey: .options) }
        case let .currency(value, options):
            try c.encode(Kind.currency, forKey: .kind); try c.encode(value, forKey: .value); try c.encode(options, forKey: .options)
        case let .date(value, options):
            try c.encode(Kind.date, forKey: .kind); try c.encode(value, forKey: .value)
            if !options.isEmpty { try c.encode(options, forKey: .options) }
        case let .plural(value, options):
            try c.encode(Kind.plural, forKey: .kind); try c.encode(value, forKey: .value)
            if !options.isEmpty { try c.encode(options, forKey: .options) }
        }
    }
}

/// Options for decimal number formatting.
public struct NumberFormatOptions: Sendable, Equatable, Codable {
    public var locale: String?
    public var minimumFractionDigits: Int?
    public var maximumFractionDigits: Int?
    public var grouping: Bool?
    public init(locale: String? = nil, minimumFractionDigits: Int? = nil, maximumFractionDigits: Int? = nil, grouping: Bool? = nil) {
        self.locale = locale; self.minimumFractionDigits = minimumFractionDigits; self.maximumFractionDigits = maximumFractionDigits; self.grouping = grouping
    }
    var isEmpty: Bool { locale == nil && minimumFractionDigits == nil && maximumFractionDigits == nil && grouping == nil }
    enum CodingKeys: String, CodingKey, CaseIterable { case locale, minimumFractionDigits, maximumFractionDigits, grouping }
    public init(from decoder: Decoder) throws {
        let c = try decoder.strictContainer(keyedBy: CodingKeys.self)
        locale = try c.decodeIfPresent(String.self, forKey: .locale); minimumFractionDigits = try c.decodeIfPresent(Int.self, forKey: .minimumFractionDigits)
        maximumFractionDigits = try c.decodeIfPresent(Int.self, forKey: .maximumFractionDigits); grouping = try c.decodeIfPresent(Bool.self, forKey: .grouping)
    }
}

/// Options for currency formatting.
public struct CurrencyFormatOptions: Sendable, Equatable, Codable {
    public var code: String
    public var locale: String?
    public init(code: String, locale: String? = nil) { self.code = code; self.locale = locale }
    enum CodingKeys: String, CodingKey, CaseIterable { case code, locale }
    public init(from decoder: Decoder) throws {
        let c = try decoder.strictContainer(keyedBy: CodingKeys.self); code = try c.decode(String.self, forKey: .code); locale = try c.decodeIfPresent(String.self, forKey: .locale)
    }
}

/// A named date/time style.
public enum DateFormatStyleName: String, Sendable, Codable, CaseIterable { case none, short, medium, long, full }

/// Options for date formatting.
public struct DateFormatOptions: Sendable, Equatable, Codable {
    public var locale: String?
    public var timeZone: String?
    public var dateStyle: DateFormatStyleName?
    public var timeStyle: DateFormatStyleName?
    public init(locale: String? = nil, timeZone: String? = nil, dateStyle: DateFormatStyleName? = nil, timeStyle: DateFormatStyleName? = nil) {
        self.locale = locale; self.timeZone = timeZone; self.dateStyle = dateStyle; self.timeStyle = timeStyle
    }
    var isEmpty: Bool { locale == nil && timeZone == nil && dateStyle == nil && timeStyle == nil }
    enum CodingKeys: String, CodingKey, CaseIterable { case locale, timeZone, dateStyle, timeStyle }
    public init(from decoder: Decoder) throws {
        let c = try decoder.strictContainer(keyedBy: CodingKeys.self); locale = try c.decodeIfPresent(String.self, forKey: .locale); timeZone = try c.decodeIfPresent(String.self, forKey: .timeZone)
        dateStyle = try c.decodeIfPresent(DateFormatStyleName.self, forKey: .dateStyle); timeStyle = try c.decodeIfPresent(DateFormatStyleName.self, forKey: .timeStyle)
    }
}

/// Options and category strings for plural formatting.
public struct PluralFormatOptions: Sendable, Equatable, Codable {
    public var locale: String?
    public var zero: String?
    public var one: String?
    public var two: String?
    public var few: String?
    public var many: String?
    public var other: String?
    public init(locale: String? = nil, zero: String? = nil, one: String? = nil, two: String? = nil, few: String? = nil, many: String? = nil, other: String? = nil) {
        self.locale = locale; self.zero = zero; self.one = one; self.two = two; self.few = few; self.many = many; self.other = other
    }
    var isEmpty: Bool { locale == nil && zero == nil && one == nil && two == nil && few == nil && many == nil && other == nil }
    enum CodingKeys: String, CodingKey, CaseIterable { case locale, zero, one, two, few, many, other }
    public init(from decoder: Decoder) throws {
        let c = try decoder.strictContainer(keyedBy: CodingKeys.self); locale = try c.decodeIfPresent(String.self, forKey: .locale); zero = try c.decodeIfPresent(String.self, forKey: .zero)
        one = try c.decodeIfPresent(String.self, forKey: .one); two = try c.decodeIfPresent(String.self, forKey: .two); few = try c.decodeIfPresent(String.self, forKey: .few)
        many = try c.decodeIfPresent(String.self, forKey: .many); other = try c.decodeIfPresent(String.self, forKey: .other)
    }
}
