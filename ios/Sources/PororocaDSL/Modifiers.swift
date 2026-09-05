import PororocaDocument

public extension Dim {
    static func space(_ name: String) -> Dim { .token(name) }
}

public extension Radius {
    static func radius(_ name: String) -> Radius { .token(name) }
}

public extension ColorValue {
    static func color(_ name: String, opacity: Double? = nil) -> ColorValue { .token(name: name, opacity: opacity) }
}

public extension FontValue {
    static func font(_ name: String) -> FontValue { .token(name) }
    static func system(size: Double, weight: FontWeight? = nil, design: FontDesign? = nil) -> FontValue { .system(.init(size: size, weight: weight, design: design)) }
}

/// A document node plus its source-ordered modifier applications.
public struct DSLNode: Sendable, Equatable {
    var base: Node
    var applications: [ModifierApplication]
    public init(_ node: Node) { base = node; applications = [] }
    public var node: Node { Canonicalizer.apply(applications, to: base) }

    private func adding(_ application: ModifierApplication) -> DSLNode { var copy = self; copy.applications.append(application); return copy }
    public func font(_ value: FontValue) -> DSLNode { adding(.font(value)) }
    public func foreground(_ value: ColorValue) -> DSLNode { adding(.foreground(value)) }
    public func lineLimit(_ value: Int) -> DSLNode { adding(.lineLimit(value)) }
    public func multilineAlignment(_ value: TextAlignment) -> DSLNode { adding(.multilineAlignment(value)) }
    public func minimumScaleFactor(_ value: Double) -> DSLNode { adding(.minimumScaleFactor(value)) }
    public func fixedSize(horizontal: Bool, vertical: Bool) -> DSLNode { adding(.fixedSize(.init(horizontal: horizontal, vertical: vertical))) }
    public func padding(_ edges: Edges = .all, _ value: Dim) -> DSLNode { adding(.padding(.init(edges: edges, value: value))) }
    public func background(_ value: Paint) -> DSLNode { adding(.background(value)) }
    public func frame(width: FrameDimension? = nil, height: FrameDimension? = nil, minWidth: FrameDimension? = nil, maxWidth: FrameDimension? = nil, minHeight: FrameDimension? = nil, maxHeight: FrameDimension? = nil, alignment: Alignment? = nil) -> DSLNode { adding(.frame(.init(width: width, height: height, minWidth: minWidth, maxWidth: maxWidth, minHeight: minHeight, maxHeight: maxHeight, alignment: alignment))) }
    public func cornerRadius(_ radius: Radius, style: CornerStyle = .continuous) -> DSLNode { adding(.cornerRadius(.init(radius: radius, style: style))) }
    public func clip(_ shape: ClipShape) -> DSLNode { adding(.clip(shape)) }
    public func border(_ color: ColorValue, width: Double) -> DSLNode { adding(.border(.init(color: color, width: width))) }
    public func shadow(_ color: ColorValue, radius: Double, x: Double = 0, y: Double = 0) -> DSLNode { adding(.shadow(.init(color: color, radius: radius, x: x, y: y))) }
    public func opacity(_ value: Double) -> DSLNode { adding(.opacity(value)) }
    public func disabled(_ expression: Expr) -> DSLNode { adding(.disabled(expression)) }
    public func hidden(_ expression: Expr) -> DSLNode { adding(.hidden(expression)) }
    public func accessibilityLabel(_ value: Str) -> DSLNode { adding(.accessibilityLabel(value)) }
    public func ignoresSafeArea(_ edges: Edges = .all) -> DSLNode { adding(.ignoresSafeArea(edges)) }
    public func id(_ value: String) -> DSLNode { adding(.id(value)) }

    public func fill(_ paint: Paint) -> DSLNode {
        var copy = self
        if case let .shape(kind, cornerRadius, _) = copy.base.kind { copy.base.kind = .shape(kind: kind, cornerRadius: cornerRadius, fill: paint) }
        return copy
    }

    public func tint(_ color: ColorValue) -> DSLNode {
        var copy = self
        if case .progress = copy.base.kind { copy.base.kind = .progress(tint: color) }
        return copy
    }

    /// Preserves SwiftUI's `Image(systemName:).font(.system(...))` sizing as
    /// intrinsic icon metadata instead of a generic text font modifier.
    public func iconFont(size: Double, weight: FontWeight? = nil) -> DSLNode {
        var copy = self
        if case let .icon(sf, material, _, _) = copy.base.kind {
            copy.base.kind = .icon(sf: sf, material: material, size: size, weight: weight)
        }
        return copy
    }
}
