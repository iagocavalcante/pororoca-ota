import SwiftUI
import PororocaExpr

@MainActor
public protocol SlotRegistry {
    func view(named name: String, props: [String: Value]) -> AnyView?
}

public struct EmptySlotRegistry: SlotRegistry {
    public init() {}
    public func view(named name: String, props: [String: Value]) -> AnyView? { nil }
}
