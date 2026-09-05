import PororocaExpr

public func pororocaValue(_ value: String) -> Value { .string(value) }
public func pororocaValue(_ value: String?) -> Value { value.map(Value.string) ?? .null }
public func pororocaValue(_ value: Bool) -> Value { .bool(value) }
public func pororocaValue(_ value: Bool?) -> Value { value.map(Value.bool) ?? .null }
public func pororocaValue(_ value: Double) -> Value { .number(value) }
public func pororocaValue(_ value: Double?) -> Value { value.map(Value.number) ?? .null }
public func pororocaValue(_ value: Int) -> Value { .number(Double(value)) }
public func pororocaValue(_ value: Int?) -> Value { value.map { .number(Double($0)) } ?? .null }
public func pororocaValue(_ value: [String]) -> Value { .array(value.map(Value.string)) }
public func pororocaValue(_ value: [Double]) -> Value { .array(value.map(Value.number)) }
public func pororocaValue(_ value: [Bool]) -> Value { .array(value.map(Value.bool)) }
