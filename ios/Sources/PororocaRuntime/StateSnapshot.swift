import Observation
import PororocaExpr

public struct StateSnapshot: Sendable, Equatable {
    public var values: [String: Value]
    public init(_ values: [String: Value] = [:]) { self.values = values }
}

@MainActor @Observable
public final class StateBox {
    public var snapshot: StateSnapshot
    public init(_ snapshot: StateSnapshot = .init()) { self.snapshot = snapshot }
}
