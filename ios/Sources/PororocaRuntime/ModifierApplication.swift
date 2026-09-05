import SwiftUI
import PororocaDocument
import PororocaExpr

struct RuntimeModifier: ViewModifier {
    let props: ModifierProps
    let environment: ExpressionEnvironment
    let host: ScreenHost

    func body(content: Content) -> some View {
        let typography = content
            .modifier(FontModifier(value: props.font, host: host))
            .modifier(ForegroundModifier(value: props.foreground, host: host))
            .lineLimit(props.lineLimit)
            .multilineTextAlignment(props.multilineAlignment?.swiftUI ?? .leading)
            .minimumScaleFactor(props.minimumScaleFactor ?? 1)
            .fixedSize(
                horizontal: props.fixedSize?.horizontal ?? false,
                vertical: props.fixedSize?.vertical ?? false
            )
        let layout = typography
            .padding(resolvedInsets)
            .modifier(BackgroundModifier(paint: props.background, host: host))
            .modifier(FrameModifier(frame: props.frame))
        let decoration = layout
            .modifier(CornerModifier(value: props.cornerRadius, host: host))
            .modifier(ClipModifier(value: props.clip))
            .modifier(BorderModifier(value: props.border, host: host))
            .modifier(ShadowModifier(value: props.shadow, host: host))
            .opacity(props.opacity ?? 1)
        return decoration
            .disabled(props.disabled.map { evaluate($0, environment).boolValue } ?? false)
            .modifier(HiddenModifier(hidden: props.hidden.map { evaluate($0, environment).boolValue } ?? false))
            .modifier(AccessibilityModifier(label: props.accessibilityLabel.map { resolve($0, environment: environment, host: host) }))
            .modifier(SafeAreaModifier(edges: props.ignoresSafeArea))
            .modifier(IdentityModifier(id: props.id))
    }

    private var resolvedInsets: EdgeInsets {
        var top: CGFloat = 0
        var leading: CGFloat = 0
        var bottom: CGFloat = 0
        var trailing: CGFloat = 0
        for padding in props.padding {
            let amount = host.tokens.resolve(padding.value) ?? 0
            let edges = padding.edges.edgeSet
            if edges.contains(where: { $0.rawValue == "top" }) { top += amount }
            if edges.contains(where: { $0.rawValue == "leading" }) { leading += amount }
            if edges.contains(where: { $0.rawValue == "bottom" }) { bottom += amount }
            if edges.contains(where: { $0.rawValue == "trailing" }) { trailing += amount }
        }
        return EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
    }
}

private struct FontModifier: ViewModifier {
    let value: FontValue?
    let host: ScreenHost
    func body(content: Content) -> some View { content.font(value.map(host.tokens.resolve)) }
}

private struct ForegroundModifier: ViewModifier {
    let value: ColorValue?
    let host: ScreenHost
    @ViewBuilder func body(content: Content) -> some View {
        if let value { content.foregroundStyle(host.tokens.resolve(value)) } else { content }
    }
}

private struct BackgroundModifier: ViewModifier {
    let paint: Paint?
    let host: ScreenHost
    @ViewBuilder func body(content: Content) -> some View {
        if let paint { content.background { PaintView(paint: paint, host: host) } } else { content }
    }
}

private struct FrameModifier: ViewModifier {
    let frame: Frame?
    func body(content: Content) -> some View {
        content
            .frame(width: frame?.width?.fixed, height: frame?.height?.fixed, alignment: frame?.alignment?.swiftUI ?? .center)
            .frame(
                minWidth: frame?.minWidth?.flexible,
                maxWidth: frame?.maxWidth?.flexible,
                minHeight: frame?.minHeight?.flexible,
                maxHeight: frame?.maxHeight?.flexible,
                alignment: frame?.alignment?.swiftUI ?? .center
            )
    }
}

private struct CornerModifier: ViewModifier {
    let value: CornerRadius?
    let host: ScreenHost
    @ViewBuilder func body(content: Content) -> some View {
        if let value {
            content.clipShape(RoundedRectangle(
                cornerRadius: host.tokens.resolve(value.radius) ?? 0,
                style: value.style == .continuous ? .continuous : .circular
            ))
        } else { content }
    }
}

private struct ClipModifier: ViewModifier {
    let value: ClipShape?
    @ViewBuilder func body(content: Content) -> some View {
        switch value {
        case .capsule: content.clipShape(Capsule())
        case .circle: content.clipShape(Circle())
        case nil: content
        }
    }
}

private struct BorderModifier: ViewModifier {
    let value: Border?
    let host: ScreenHost
    @ViewBuilder func body(content: Content) -> some View {
        if let value {
            content.overlay { Rectangle().stroke(host.tokens.resolve(value.color), lineWidth: value.width) }
        } else { content }
    }
}

private struct ShadowModifier: ViewModifier {
    let value: Shadow?
    let host: ScreenHost
    @ViewBuilder func body(content: Content) -> some View {
        if let value {
            content.shadow(color: host.tokens.resolve(value.color), radius: value.radius, x: value.x, y: value.y)
        } else { content }
    }
}

private struct HiddenModifier: ViewModifier {
    let hidden: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if hidden { content.hidden() } else { content }
    }
}

private struct AccessibilityModifier: ViewModifier {
    let label: String?
    @ViewBuilder func body(content: Content) -> some View {
        if let label { content.accessibilityLabel(Text(label)) } else { content }
    }
}

private struct SafeAreaModifier: ViewModifier {
    let edges: Edges?
    @ViewBuilder func body(content: Content) -> some View {
        if let edges { content.ignoresSafeArea(edges: edges.swiftUI) } else { content }
    }
}

private struct IdentityModifier: ViewModifier {
    let id: String?
    @ViewBuilder func body(content: Content) -> some View {
        if let id { content.id(id) } else { content }
    }
}

struct PaintView: View {
    let paint: Paint
    let host: ScreenHost
    @ViewBuilder var body: some View {
        switch paint {
        case let .color(color): host.tokens.resolve(color)
        case let .gradient(.linear(value)):
            LinearGradient(
                colors: value.colors.map(host.tokens.resolve),
                startPoint: value.start.swiftUI,
                endPoint: value.end.swiftUI
            )
        }
    }
}

extension Value {
    var boolValue: Bool { if case let .bool(value) = self { value } else { false } }
}

extension FrameDimension {
    var fixed: CGFloat? { if case let .points(value) = self { CGFloat(value) } else { nil } }
    var flexible: CGFloat? { switch self { case let .points(value): CGFloat(value); case .infinity: .infinity } }
}

extension DocumentHorizontalAlignment {
    var swiftUI: SwiftUI.HorizontalAlignment { switch self { case .leading: .leading; case .center: .center; case .trailing: .trailing } }
}

extension DocumentVerticalAlignment {
    var swiftUI: SwiftUI.VerticalAlignment { switch self { case .top: .top; case .center: .center; case .bottom: .bottom; case .firstTextBaseline: .firstTextBaseline; case .lastTextBaseline: .lastTextBaseline } }
}

extension DocumentAlignment {
    var swiftUI: SwiftUI.Alignment {
        switch self { case .center: .center; case .top: .top; case .bottom: .bottom; case .leading: .leading; case .trailing: .trailing; case .topLeading: .topLeading; case .topTrailing: .topTrailing; case .bottomLeading: .bottomLeading; case .bottomTrailing: .bottomTrailing }
    }
}

extension DocumentTextAlignment {
    var swiftUI: SwiftUI.TextAlignment { switch self { case .leading: .leading; case .center: .center; case .trailing: .trailing } }
}

extension UnitPointName {
    var swiftUI: UnitPoint {
        switch self { case .top: .top; case .bottom: .bottom; case .leading: .leading; case .trailing: .trailing; case .topLeading: .topLeading; case .topTrailing: .topTrailing; case .bottomLeading: .bottomLeading; case .bottomTrailing: .bottomTrailing; case .center: .center }
    }
}

extension Edges {
    var swiftUI: SwiftUI.Edge.Set {
        var result: SwiftUI.Edge.Set = []
        if edgeSet.contains(where: { $0.rawValue == "top" }) { result.insert(SwiftUI.Edge.Set.top) }
        if edgeSet.contains(where: { $0.rawValue == "bottom" }) { result.insert(SwiftUI.Edge.Set.bottom) }
        if edgeSet.contains(where: { $0.rawValue == "leading" }) { result.insert(SwiftUI.Edge.Set.leading) }
        if edgeSet.contains(where: { $0.rawValue == "trailing" }) { result.insert(SwiftUI.Edge.Set.trailing) }
        return result
    }
}

@MainActor
func resolve(_ string: Str, environment: ExpressionEnvironment, host: ScreenHost) -> String {
    switch string {
    case let .literal(value): value
    case let .localized(key): host.localizer.string(for: key)
    case let .expr(expression): evaluate(expression, environment).displayString
    }
}

private extension Value {
    var displayString: String {
        switch self {
        case .null: ""
        case let .string(value): value
        case let .number(value): value.rounded() == value ? String(Int(value)) : String(value)
        case let .bool(value): value ? "true" : "false"
        case .array, .object: ""
        }
    }
}
