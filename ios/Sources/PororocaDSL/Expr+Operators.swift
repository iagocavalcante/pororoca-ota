import PororocaDocument
import PororocaExpr

/// Creates a localized-string expression.
public func t(_ key: String) -> Expr { .localized(key) }

public func == (lhs: Expr, rhs: String) -> Expr { .eq(lhs, .literal(.string(rhs))) }
public func != (lhs: Expr, rhs: String) -> Expr { .ne(lhs, .literal(.string(rhs))) }
public func == (lhs: Expr, rhs: Bool) -> Expr { .eq(lhs, .literal(.bool(rhs))) }
public func != (lhs: Expr, rhs: Bool) -> Expr { .ne(lhs, .literal(.bool(rhs))) }
public func == (lhs: Expr, rhs: Double) -> Expr { .eq(lhs, .literal(.number(rhs))) }
public func != (lhs: Expr, rhs: Double) -> Expr { .ne(lhs, .literal(.number(rhs))) }
public func == (lhs: Expr, rhs: Int) -> Expr { lhs == Double(rhs) }
public func != (lhs: Expr, rhs: Int) -> Expr { lhs != Double(rhs) }
public func == (lhs: Expr, rhs: _OptionalNilComparisonType) -> Expr { .eq(lhs, .literal(.null)) }
public func != (lhs: Expr, rhs: _OptionalNilComparisonType) -> Expr { .ne(lhs, .literal(.null)) }
public func < (lhs: Expr, rhs: Double) -> Expr { .lt(lhs, .literal(.number(rhs))) }
public func <= (lhs: Expr, rhs: Double) -> Expr { .le(lhs, .literal(.number(rhs))) }
public func > (lhs: Expr, rhs: Double) -> Expr { .gt(lhs, .literal(.number(rhs))) }
public func >= (lhs: Expr, rhs: Double) -> Expr { .ge(lhs, .literal(.number(rhs))) }
public func < (lhs: Expr, rhs: Int) -> Expr { lhs < Double(rhs) }
public func <= (lhs: Expr, rhs: Int) -> Expr { lhs <= Double(rhs) }
public func > (lhs: Expr, rhs: Int) -> Expr { lhs > Double(rhs) }
public func >= (lhs: Expr, rhs: Int) -> Expr { lhs >= Double(rhs) }
public prefix func ! (value: Expr) -> Expr { .not(value) }
public func && (lhs: Expr, rhs: Expr) -> Expr { .and([lhs, rhs]) }
public func || (lhs: Expr, rhs: Expr) -> Expr { .or([lhs, rhs]) }
public func ?? (lhs: Expr, rhs: @autoclosure () -> String) -> Expr { .coalesce([lhs, .literal(.string(rhs()))]) }
public func ?? (lhs: Expr, rhs: @autoclosure () -> Expr) -> Expr { .coalesce([lhs, rhs()]) }

/// String interpolation storage that emits a concat expression.
public struct DSLStringInterpolation: StringInterpolationProtocol {
    var components: [Expr] = []
    public init(literalCapacity: Int, interpolationCount: Int) { components.reserveCapacity(interpolationCount * 2 + 1) }
    public mutating func appendLiteral(_ literal: String) { if !literal.isEmpty { components.append(.literal(.string(literal))) } }
    public mutating func appendInterpolation(_ expression: Expr) { components.append(expression) }
}

extension Str: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    public typealias StringInterpolation = DSLStringInterpolation
    public init(stringLiteral value: String) { self = .literal(value) }
    public init(stringInterpolation: DSLStringInterpolation) { self = .expr(.concat(stringInterpolation.components)) }
}
