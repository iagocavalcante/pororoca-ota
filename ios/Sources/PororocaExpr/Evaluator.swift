import Foundation

/// Evaluates an expression against an immutable environment.
public func evaluate(_ expression: Expr, _ environment: Environment) -> Value {
    Evaluator.evaluate(expression, environment)
}

/// The pure, total evaluator for the Pororoca expression AST.
public enum Evaluator {
    /// Evaluates an expression, returning `.null` for type errors and excessive depth.
    public static func evaluate(_ expression: Expr, _ environment: Environment) -> Value {
        evaluate(expression, environment, depth: 0)
    }

    private static func evaluate(_ expression: Expr, _ environment: Environment, depth: Int) -> Value {
        guard depth <= 64 else { return .null }
        let next = depth + 1

        switch expression {
        case let .literal(value):
            return value
        case let .state(key):
            return environment.state[key] ?? .null
        case let .local(key):
            return environment.local[key] ?? .null
        case let .item(key):
            return environment.item?[key] ?? .null
        case .index:
            return environment.index.map { .number(Double($0)) } ?? .null
        case let .localized(key):
            return environment.strings[key].map(Value.string) ?? .null
        case let .eq(lhs, rhs):
            return .bool(equals(evaluate(lhs, environment, depth: next), evaluate(rhs, environment, depth: next)))
        case let .ne(lhs, rhs):
            return .bool(!equals(evaluate(lhs, environment, depth: next), evaluate(rhs, environment, depth: next)))
        case let .lt(lhs, rhs):
            return order(lhs, rhs, environment, depth: next, by: <)
        case let .le(lhs, rhs):
            return order(lhs, rhs, environment, depth: next, by: <=)
        case let .gt(lhs, rhs):
            return order(lhs, rhs, environment, depth: next, by: >)
        case let .ge(lhs, rhs):
            return order(lhs, rhs, environment, depth: next, by: >=)
        case let .and(expressions):
            let values = expressions.map { evaluate($0, environment, depth: next) }
            guard values.allSatisfy({ if case .bool = $0 { true } else { false } }) else { return .null }
            return .bool(values.allSatisfy { if case let .bool(value) = $0 { value } else { false } })
        case let .or(expressions):
            let values = expressions.map { evaluate($0, environment, depth: next) }
            guard values.allSatisfy({ if case .bool = $0 { true } else { false } }) else { return .null }
            return .bool(values.contains { if case let .bool(value) = $0 { value } else { false } })
        case let .not(expression):
            guard case let .bool(value) = evaluate(expression, environment, depth: next) else { return .null }
            return .bool(!value)
        case let .coalesce(expressions):
            for expression in expressions {
                let value = evaluate(expression, environment, depth: next)
                if value != .null { return value }
            }
            return .null
        case let .concat(expressions):
            var result = ""
            for expression in expressions {
                guard let component = stringComponent(evaluate(expression, environment, depth: next)) else { return .null }
                result += component
            }
            return .string(result)
        case let .fmt(format):
            return formatValue(format, environment, depth: next)
        case let .case(on, cases, defaultExpression):
            let value = evaluate(on, environment, depth: next)
            if let key = caseKey(value), let match = cases[key] { return evaluate(match, environment, depth: next) }
            return defaultExpression.map { evaluate($0, environment, depth: next) } ?? .null
        case let .count(expression):
            switch evaluate(expression, environment, depth: next) {
            case let .array(values): return .number(Double(values.count))
            case let .string(value): return .number(Double(value.count))
            default: return .null
            }
        case let .empty(expression):
            switch evaluate(expression, environment, depth: next) {
            case let .array(values): return .bool(values.isEmpty)
            case let .string(value): return .bool(value.isEmpty)
            default: return .null
            }
        }
    }

    private static func equals(_ lhs: Value, _ rhs: Value) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): true
        case let (.bool(a), .bool(b)): a == b
        case let (.number(a), .number(b)): a == b
        case let (.string(a), .string(b)): a == b
        case let (.array(a), .array(b)): a == b
        case let (.object(a), .object(b)): a == b
        default: false
        }
    }

    private static func order(
        _ lhs: Expr,
        _ rhs: Expr,
        _ environment: Environment,
        depth: Int,
        by predicate: (Double, Double) -> Bool
    ) -> Value {
        guard case let .number(a) = evaluate(lhs, environment, depth: depth),
              case let .number(b) = evaluate(rhs, environment, depth: depth)
        else { return .bool(false) }
        return .bool(predicate(a, b))
    }

    private static func stringComponent(_ value: Value) -> String? {
        switch value {
        case .null: ""
        case let .string(value): value
        case let .number(value): numberString(value)
        case let .bool(value): value ? "true" : "false"
        case .array, .object: nil
        }
    }

    private static func numberString(_ value: Double) -> String {
        value.rounded(.towardZero) == value ? String(format: "%.0f", value) : String(value)
    }

    private static func caseKey(_ value: Value) -> String? {
        switch value {
        case let .string(value): value
        case let .number(value): numberString(value)
        case let .bool(value): value ? "true" : "false"
        case .null, .array, .object: nil
        }
    }

    private static func formatValue(_ format: Format, _ environment: Environment, depth: Int) -> Value {
        switch format {
        case let .number(expression, options):
            guard case let .number(value) = evaluate(expression, environment, depth: depth), value.isFinite else { return .null }
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = options.locale.map(Locale.init(identifier:)) ?? .current
            if let minimum = options.minimumFractionDigits { formatter.minimumFractionDigits = minimum }
            if let maximum = options.maximumFractionDigits { formatter.maximumFractionDigits = maximum }
            if let grouping = options.grouping { formatter.usesGroupingSeparator = grouping }
            return formatter.string(from: NSNumber(value: value)).map(Value.string) ?? .null
        case let .currency(expression, options):
            guard case let .number(value) = evaluate(expression, environment, depth: depth), value.isFinite else { return .null }
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = options.locale.map(Locale.init(identifier:)) ?? .current
            formatter.currencyCode = options.code
            return formatter.string(from: NSNumber(value: value)).map(Value.string) ?? .null
        case let .date(expression, options):
            guard case let .number(value) = evaluate(expression, environment, depth: depth), value.isFinite else { return .null }
            let formatter = DateFormatter()
            formatter.locale = options.locale.map(Locale.init(identifier:)) ?? .current
            if let identifier = options.timeZone { formatter.timeZone = TimeZone(identifier: identifier) }
            formatter.dateStyle = dateStyle(options.dateStyle ?? .medium)
            formatter.timeStyle = dateStyle(options.timeStyle ?? .none)
            return .string(formatter.string(from: Date(timeIntervalSince1970: value)))
        case let .plural(expression, options):
            guard case let .number(value) = evaluate(expression, environment, depth: depth), value.isFinite else { return .null }
            let selected: String?
            if value == 0, let zero = options.zero { selected = zero }
            else if value == 1, let one = options.one { selected = one }
            else if value == 2, let two = options.two { selected = two }
            else { selected = options.other }
            return selected.map(Value.string) ?? .null
        }
    }

    private static func dateStyle(_ style: DateFormatStyleName) -> DateFormatter.Style {
        switch style {
        case .none: .none
        case .short: .short
        case .medium: .medium
        case .long: .long
        case .full: .full
        }
    }
}
