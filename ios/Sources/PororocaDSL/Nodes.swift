import PororocaDocument
import PororocaExpr

/// Collects document nodes from declarative DSL closures.
@resultBuilder
public enum NodesBuilder {
    public static func buildExpression(_ expression: DSLNode) -> [DSLNode] { [expression] }
    public static func buildExpression(_ expression: Node) -> [DSLNode] { [DSLNode(expression)] }
    public static func buildBlock(_ components: [DSLNode]...) -> [DSLNode] { components.flatMap { $0 } }
    public static func buildOptional(_ component: [DSLNode]?) -> [DSLNode] { component ?? [] }
    public static func buildEither(first component: [DSLNode]) -> [DSLNode] { component }
    public static func buildEither(second component: [DSLNode]) -> [DSLNode] { component }
    public static func buildArray(_ components: [[DSLNode]]) -> [DSLNode] { components.flatMap { $0 } }
}

private func nodes(_ values: [DSLNode]) -> [Node] { values.map(\.node) }
private func singleNode(_ values: [DSLNode]) -> Node {
    let built = nodes(values)
    if built.count == 1, let only = built.first { return only }
    return Node(.vstack(spacing: nil, alignment: nil, children: built))
}

public func VStack(spacing: Dim? = nil, alignment: HorizontalAlignment? = nil, @NodesBuilder _ content: () -> [DSLNode]) -> DSLNode { DSLNode(Node(.vstack(spacing: spacing, alignment: alignment, children: nodes(content())))) }
public func HStack(spacing: Dim? = nil, alignment: VerticalAlignment? = nil, @NodesBuilder _ content: () -> [DSLNode]) -> DSLNode { DSLNode(Node(.hstack(spacing: spacing, alignment: alignment, children: nodes(content())))) }
public func ZStack(alignment: Alignment? = nil, @NodesBuilder _ content: () -> [DSLNode]) -> DSLNode { DSLNode(Node(.zstack(alignment: alignment, children: nodes(content())))) }
public func Box(@NodesBuilder _ content: () -> [DSLNode]) -> DSLNode { DSLNode(Node(.box(child: singleNode(content())))) }
public func Spacer(minLength: Dim? = nil) -> DSLNode { DSLNode(Node(.spacer(minLength: minLength))) }
public func ScrollView(axis: Axis? = nil, @NodesBuilder _ content: () -> [DSLNode]) -> DSLNode { DSLNode(Node(.scroll(axis: axis, child: singleNode(content())))) }
public func LazyColumn(spacing: Dim? = nil, @NodesBuilder _ content: () -> [DSLNode]) -> DSLNode { DSLNode(Node(.lazycolumn(spacing: spacing, children: nodes(content())))) }
public func Text(_ value: Str) -> DSLNode { DSLNode(Node(.text(value: value))) }
public func Text(expression: Expr) -> DSLNode { DSLNode(Node(.text(value: .expr(expression)))) }
public func Text(_ expression: Expr) -> DSLNode { Text(expression: expression) }
public func Icon(_ systemName: String, material: String? = nil, size: Double? = nil, weight: FontWeight? = nil) -> DSLNode { DSLNode(Node(.icon(sf: systemName, material: material, size: size, weight: weight))) }
public func Image(bundled name: String, contentMode: ContentMode? = nil) -> DSLNode { DSLNode(Node(.image(source: .bundled(name), contentMode: contentMode))) }
public func Image(asset hash: String, contentMode: ContentMode? = nil) -> DSLNode { DSLNode(Node(.image(source: .asset(hash), contentMode: contentMode))) }
public func Rectangle() -> DSLNode { DSLNode(Node(.shape(kind: .rect, cornerRadius: nil, fill: nil))) }
public func RoundedRectangle(cornerRadius: Radius, style: CornerStyle = .continuous) -> DSLNode { DSLNode(Node(.shape(kind: .rounded, cornerRadius: cornerRadius, fill: nil))) }
public func Capsule() -> DSLNode { DSLNode(Node(.shape(kind: .capsule, cornerRadius: nil, fill: nil))) }
public func Circle() -> DSLNode { DSLNode(Node(.shape(kind: .circle, cornerRadius: nil, fill: nil))) }
public func Divider() -> DSLNode { DSLNode(Node(.divider)) }
public func Progress(tint: ColorValue? = nil) -> DSLNode { DSLNode(Node(.progress(tint: tint))) }

public func Button<A: ScreenAction>(_ action: A, args: [String: Expr] = [:], role: ButtonRole? = nil, @NodesBuilder _ label: () -> [DSLNode]) -> DSLNode {
    DSLNode(Node(.button(action: .init(name: action.rawValue, args: args), role: role, label: singleNode(label()))))
}

public func Button(_ action: Action, role: ButtonRole? = nil, @NodesBuilder _ label: () -> [DSLNode]) -> DSLNode {
    DSLNode(Node(.button(action: action, role: role, label: singleNode(label()))))
}

public func If(_ condition: Expr, @NodesBuilder _ thenContent: () -> [DSLNode]) -> DSLNode {
    DSLNode(Node(.if(cond: condition, then: singleNode(thenContent()), else: nil)))
}

public func If(_ condition: Expr, @NodesBuilder _ thenContent: () -> [DSLNode], @NodesBuilder else elseContent: () -> [DSLNode]) -> DSLNode {
    DSLNode(Node(.if(cond: condition, then: singleNode(thenContent()), else: singleNode(elseContent()))))
}

public func ForEach(_ items: Expr, key: String, @NodesBuilder _ template: () -> [DSLNode]) -> DSLNode {
    DSLNode(Node(.foreach(items: items, key: key, template: singleNode(template()))))
}

public func ForEach(_ items: Expr, key: String, @NodesBuilder _ template: (ItemRef) -> [DSLNode]) -> DSLNode {
    DSLNode(Node(.foreach(items: items, key: key, template: singleNode(template(ItemRef())))))
}

public func Slot(_ name: String, props: [String: SlotProp] = [:]) -> DSLNode { DSLNode(Node(.slot(name: name, props: props))) }
