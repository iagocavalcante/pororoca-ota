import PororocaDocument
import PororocaExpr

/// Builds a complete screen document and derives its resource requirements.
public func Screen<State: ScreenState, A: ScreenAction>(
    _ id: String,
    platform: Platform = .ios,
    runtime: String = ">=1.0",
    state: State.Type,
    actions: A.Type,
    localDefaults: [String: Value] = [:],
    _ content: (StateRef<State>, LocalRef) -> DSLNode
) -> Document {
    let root = content(StateRef(), LocalRef()).node
    var resources = ResourceCollector()
    resources.visit(root)
    return Document(
        screen: id,
        platform: platform,
        requires: Requires(
            runtime: runtime,
            state: State.schema,
            actions: A.names,
            slots: resources.slots.sorted(),
            tokens: .init(
                color: resources.colors.sorted(),
                space: resources.spaces.sorted(),
                radius: resources.radii.sorted(),
                font: resources.fonts.sorted()
            ),
            strings: resources.strings.sorted(),
            assets: resources.assets.sorted()
        ),
        local: localDefaults,
        root: root
    )
}

private struct ResourceCollector {
    var colors: Set<String> = []
    var spaces: Set<String> = []
    var radii: Set<String> = []
    var fonts: Set<String> = []
    var strings: Set<String> = []
    var assets: Set<String> = []
    var slots: Set<String> = []

    mutating func visit(_ node: Node) {
        if let mod = node.mod { visit(mod) }
        switch node.kind {
        case let .vstack(spacing, _, children), let .hstack(spacing, _, children): visit(spacing); children.forEach { visit($0) }
        case let .zstack(_, children): children.forEach { visit($0) }
        case let .box(child), let .scroll(_, child): visit(child)
        case let .spacer(minLength): visit(minLength)
        case let .lazycolumn(spacing, children): visit(spacing); children.forEach { visit($0) }
        case let .text(value): visit(value)
        case .icon: break
        case let .image(source, _): if case let .asset(name) = source { assets.insert(name) }
        case let .shape(_, radius, fill): visit(radius); visit(fill)
        case .divider: break
        case let .progress(tint): visit(tint)
        case let .button(action, _, label): action.args.values.forEach { visit($0) }; visit(label)
        case let .if(condition, thenNode, elseNode): visit(condition); visit(thenNode); if let elseNode { visit(elseNode) }
        case let .foreach(items, _, template): visit(items); visit(template)
        case let .slot(name, props): slots.insert(name); for prop in props.values { if case let .string(value) = prop { visit(value) } }
        }
    }

    mutating func visit(_ mod: ModifierProps) {
        if case let .token(name)? = mod.font { fonts.insert(name) }
        visit(mod.foreground)
        mod.padding.forEach { visit($0.value) }
        visit(mod.background)
        visit(mod.cornerRadius?.radius)
        if let border = mod.border { visit(border.color) }
        if let shadow = mod.shadow { visit(shadow.color) }
        if let disabled = mod.disabled { visit(disabled) }
        if let hidden = mod.hidden { visit(hidden) }
        if let label = mod.accessibilityLabel { visit(label) }
    }

    mutating func visit(_ value: Dim?) { if case let .token(name)? = value { spaces.insert(name) } }
    mutating func visit(_ value: Radius?) { if case let .token(name)? = value { radii.insert(name) } }
    mutating func visit(_ value: ColorValue?) { if case let .token(name, _)? = value { colors.insert(name) } }
    mutating func visit(_ value: Paint?) { guard let value else { return }; switch value { case let .color(color): visit(color); case let .gradient(.linear(gradient)): gradient.colors.forEach { visit($0) } } }
    mutating func visit(_ value: Str) { switch value { case .literal: break; case let .localized(key): strings.insert(key); case let .expr(expression): visit(expression) } }
    mutating func visit(_ expression: Expr) {
        switch expression {
        case let .localized(key): strings.insert(key)
        case let .eq(a, b), let .ne(a, b), let .lt(a, b), let .le(a, b), let .gt(a, b), let .ge(a, b): visit(a); visit(b)
        case let .and(values), let .or(values), let .coalesce(values), let .concat(values): values.forEach { visit($0) }
        case let .not(value), let .count(value), let .empty(value): visit(value)
        case let .fmt(format): switch format { case let .number(value, _), let .currency(value, _), let .date(value, _), let .plural(value, _): visit(value) }
        case let .case(on, cases, defaultValue): visit(on); cases.values.forEach { visit($0) }; if let defaultValue { visit(defaultValue) }
        case .literal, .state, .local, .item, .index: break
        }
    }
}
