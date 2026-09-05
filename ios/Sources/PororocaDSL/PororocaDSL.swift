@_exported import PororocaDocument
@_exported import PororocaExpr

/// PororocaDSL: result-builder DSL that builds document nodes (never views) and the
/// canonical modifier resolution shared with the macro (contract C3).
///
/// This module must never import SwiftUI.
public enum PororocaDSL {
    public static let moduleName = "PororocaDSL"

    public static func Screen<State: ScreenState, A: ScreenAction>(
        _ id: String,
        state: State.Type,
        actions: A.Type,
        _ content: (StateRef<State>, LocalRef) -> DSLNode
    ) -> Document {
        PororocaDSLScreen(id, state: state, actions: actions, content)
    }

    public static func VStack(spacing: Dim? = nil, alignment: HorizontalAlignment? = nil, @NodesBuilder _ content: () -> [DSLNode]) -> DSLNode {
        SwiftVStack(spacing: spacing, alignment: alignment, content)
    }
    public static func HStack(spacing: Dim? = nil, alignment: VerticalAlignment? = nil, @NodesBuilder _ content: () -> [DSLNode]) -> DSLNode {
        SwiftHStack(spacing: spacing, alignment: alignment, content)
    }
    public static func ZStack(alignment: Alignment? = nil, @NodesBuilder _ content: () -> [DSLNode]) -> DSLNode { SwiftZStack(alignment: alignment, content) }
    public static func ScrollView(@NodesBuilder _ content: () -> [DSLNode]) -> DSLNode { SwiftScrollView(content) }
    public static func Spacer(minLength: Dim? = nil) -> DSLNode { SwiftSpacer(minLength: minLength) }
    public static func Text(_ value: Str) -> DSLNode { SwiftText(value) }
    public static func Text(_ expression: Expr) -> DSLNode { SwiftText(expression) }
    public static func Icon(_ name: String) -> DSLNode { SwiftIcon(name) }
    public static func Rectangle() -> DSLNode { SwiftRectangle() }
    public static func RoundedRectangle(cornerRadius: Radius) -> DSLNode { SwiftRoundedRectangle(cornerRadius: cornerRadius) }
    public static func Capsule() -> DSLNode { SwiftCapsule() }
    public static func Circle() -> DSLNode { SwiftCircle() }
    public static func Divider() -> DSLNode { SwiftDivider() }
    public static func Progress() -> DSLNode { SwiftProgress() }
    public static func ForEach(_ items: Expr, key: String, @NodesBuilder _ template: (ItemRef) -> [DSLNode]) -> DSLNode { SwiftForEach(items, key, template) }
    public static func Button<A: ScreenAction>(_ action: A, @NodesBuilder _ label: () -> [DSLNode]) -> DSLNode { SwiftButton(action, label) }
    public static func If(_ condition: Expr, @NodesBuilder _ content: () -> [DSLNode]) -> DSLNode { SwiftIf(condition, content) }
    public static func If(_ condition: Expr, @NodesBuilder _ content: () -> [DSLNode], @NodesBuilder else alternate: () -> [DSLNode]) -> DSLNode { SwiftIfElse(condition, content, alternate) }
}

private func PororocaDSLScreen<State: ScreenState, A: ScreenAction>(_ id: String, state: State.Type, actions: A.Type, _ content: (StateRef<State>, LocalRef) -> DSLNode) -> Document {
    Screen(id, state: state, actions: actions, content)
}
private func SwiftVStack(spacing: Dim?, alignment: HorizontalAlignment?, _ content: () -> [DSLNode]) -> DSLNode { VStack(spacing: spacing, alignment: alignment, content) }
private func SwiftHStack(spacing: Dim?, alignment: VerticalAlignment?, _ content: () -> [DSLNode]) -> DSLNode { HStack(spacing: spacing, alignment: alignment, content) }
private func SwiftZStack(alignment: Alignment?, _ content: () -> [DSLNode]) -> DSLNode { ZStack(alignment: alignment, content) }
private func SwiftScrollView(_ content: () -> [DSLNode]) -> DSLNode { ScrollView(content) }
private func SwiftSpacer(minLength: Dim?) -> DSLNode { Spacer(minLength: minLength) }
private func SwiftText(_ value: Str) -> DSLNode { Text(value) }
private func SwiftText(_ expression: Expr) -> DSLNode { Text(expression) }
private func SwiftIcon(_ name: String) -> DSLNode { Icon(name) }
private func SwiftRectangle() -> DSLNode { Rectangle() }
private func SwiftRoundedRectangle(cornerRadius: Radius) -> DSLNode { RoundedRectangle(cornerRadius: cornerRadius) }
private func SwiftCapsule() -> DSLNode { Capsule() }
private func SwiftCircle() -> DSLNode { Circle() }
private func SwiftDivider() -> DSLNode { Divider() }
private func SwiftProgress() -> DSLNode { Progress() }
private func SwiftForEach(_ items: Expr, _ key: String, _ template: (ItemRef) -> [DSLNode]) -> DSLNode { ForEach(items, key: key, template) }
private func SwiftButton<A: ScreenAction>(_ action: A, _ label: () -> [DSLNode]) -> DSLNode { Button(action, label) }
private func SwiftIf(_ condition: Expr, _ content: () -> [DSLNode]) -> DSLNode { If(condition, content) }
private func SwiftIfElse(_ condition: Expr, _ content: () -> [DSLNode], _ alternate: () -> [DSLNode]) -> DSLNode { If(condition, content, else: alternate) }
