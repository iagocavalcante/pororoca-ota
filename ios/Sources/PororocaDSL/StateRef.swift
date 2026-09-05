import PororocaExpr

/// An untyped dynamic reference to a declared screen-state key.
@dynamicMemberLookup
public struct StateRef<State: ScreenState>: Sendable {
    public init() {}
    public subscript(dynamicMember key: String) -> Expr { .state(key) }
}

/// An untyped dynamic reference to a screen-local key.
@dynamicMemberLookup
public struct LocalRef: Sendable {
    public init() {}
    public subscript(dynamicMember key: String) -> Expr { .local(key) }
}

/// An untyped dynamic reference to the current foreach item.
@dynamicMemberLookup
public struct ItemRef: Sendable {
    public init() {}
    public subscript(dynamicMember key: String) -> Expr { .item(key) }
    public var index: Expr { .index }
}
