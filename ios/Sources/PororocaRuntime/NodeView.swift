import SwiftUI
import PororocaDocument
import PororocaExpr

@MainActor
public struct NodeView: View {
    public let node: Node
    public let state: StateBox
    @Binding public var local: [String: Value]
    public let strings: [String: String]
    public let host: ScreenHost
    public let onAction: ActionHandler
    let item: [String: Value]?
    let index: Int?
    let insideScroll: Bool

    public init(
        node: Node,
        state: StateBox,
        local: Binding<[String: Value]>,
        strings: [String: String],
        host: ScreenHost,
        onAction: @escaping ActionHandler
    ) {
        self.init(node: node, state: state, local: local, strings: strings, host: host, onAction: onAction, item: nil, index: nil, insideScroll: false)
    }

    init(
        node: Node,
        state: StateBox,
        local: Binding<[String: Value]>,
        strings: [String: String],
        host: ScreenHost,
        onAction: @escaping ActionHandler,
        item: [String: Value]?,
        index: Int?,
        insideScroll: Bool
    ) {
        self.node = node
        self.state = state
        self._local = local
        self.strings = strings
        self.host = host
        self.onAction = onAction
        self.item = item
        self.index = index
        self.insideScroll = insideScroll
    }

    @ViewBuilder public var body: some View {
        if let props = node.mod {
            content.modifier(RuntimeModifier(props: props, environment: expressionEnvironment, host: host))
        } else {
            content
        }
    }

    @ViewBuilder private var content: some View {
        switch node.kind {
        case let .vstack(spacing, alignment, children):
            VStack(alignment: alignment?.swiftUI ?? .center, spacing: host.tokens.resolve(spacing)) {
                childrenView(children)
            }
        case let .hstack(spacing, alignment, children):
            HStack(alignment: alignment?.swiftUI ?? .center, spacing: host.tokens.resolve(spacing)) {
                childrenView(children)
            }
        case let .zstack(alignment, children):
            ZStack(alignment: alignment?.swiftUI ?? .center) { childrenView(children) }
        case let .box(child):
            childView(child)
        case let .spacer(minLength):
            Spacer(minLength: host.tokens.resolve(minLength))
        case let .scroll(axis, child):
            ScrollView(axis == .horizontal ? .horizontal : .vertical) { childView(child, insideScroll: true) }
                .defaultScrollAnchor(.top)
        case let .lazycolumn(spacing, children):
            if insideScroll {
                LazyVStack(spacing: host.tokens.resolve(spacing)) { childrenView(children) }
            } else {
                ScrollView { LazyVStack(spacing: host.tokens.resolve(spacing)) { childrenView(children) } }
                    .defaultScrollAnchor(.top)
            }
        case let .text(value):
            Text(resolve(value, environment: expressionEnvironment, host: host))
        case let .icon(sf, _, size, weight):
            Image(systemName: sf).font(.system(size: size ?? 17, weight: weight?.swiftUI ?? .regular))
        case let .image(source, contentMode):
            runtimeImage(source).resizable().aspectRatio(contentMode: contentMode == .fill ? .fill : .fit)
        case let .shape(kind, cornerRadius, fill):
            ShapeView(kind: kind, radius: host.tokens.resolve(cornerRadius), paint: fill ?? .color(.hex(HexColor("#000000")!)), host: host)
        case .divider:
            Divider()
        case let .progress(tint):
            ProgressView().tint(tint.map(host.tokens.resolve))
        case let .button(action, role, label):
            Button(role: role.swiftUI) { dispatch(action) } label: { childView(label) }
                .buttonStyle(.plain)
        case let .if(condition, thenNode, elseNode):
            if evaluate(condition, expressionEnvironment).boolValue { childView(thenNode) } else if let elseNode { childView(elseNode) }
        case let .foreach(itemsExpression, key, template):
            let rows = rows(evaluate(itemsExpression, expressionEnvironment), key: key)
            ForEach(rows) { row in childView(template, item: row.item, index: row.index) }
        case let .slot(name, props):
            if let view = host.slots.view(named: name, props: resolved(props)) { view }
        }
    }

    @ViewBuilder private func childrenView(_ children: [Node]) -> some View {
        ForEach(Array(children.enumerated()), id: \.offset) { _, child in childView(child) }
    }

    private func childView(_ child: Node, item: [String: Value]? = nil, index: Int? = nil, insideScroll: Bool? = nil) -> NodeView {
        NodeView(node: child, state: state, local: $local, strings: strings, host: host, onAction: onAction, item: item ?? self.item, index: index ?? self.index, insideScroll: insideScroll ?? self.insideScroll)
    }

    private var expressionEnvironment: ExpressionEnvironment {
        ExpressionEnvironment(state: state.snapshot.values, local: local, strings: strings, item: item, index: index)
    }

    private func runtimeImage(_ source: ImageSource) -> Image {
        switch source { case let .bundled(name), let .asset(name): Image(name) }
    }

    private func dispatch(_ action: Action) {
        let args = action.args.mapValues { evaluate($0, expressionEnvironment) }
        if action.name == "setLocal", case let .string(key)? = args["key"], let value = args["value"] { local[key] = value }
        onAction(action.name, args)
    }

    private func resolved(_ props: [String: SlotProp]) -> [String: Value] {
        props.mapValues { prop in
            switch prop {
            case let .string(value): .string(resolve(value, environment: expressionEnvironment, host: host))
            case let .number(value): .number(value)
            case let .bool(value): .bool(value)
            }
        }
    }

    private func rows(_ value: Value, key: String) -> [RuntimeRow] {
        runtimeRows(value, key: key)
    }
}

struct RuntimeRow: Identifiable {
    let id: StableID
    let item: [String: Value]
    let index: Int
}

struct StableID: Hashable {
    let raw: String
    init(_ value: Value) {
        switch value {
        case .null: raw = "null"
        case let .bool(value): raw = "b:\(value)"
        case let .number(value): raw = "n:\(value)"
        case let .string(value): raw = "s:\(value)"
        case let .array(value): raw = "a:\(value.count):\(String(describing: value))"
        case let .object(value): raw = "o:\(value.keys.sorted().map { "\($0)=\(String(describing: value[$0]!))" }.joined(separator: ","))"
        }
    }
}

func runtimeRows(_ value: Value, key: String) -> [RuntimeRow] {
    guard case let .array(values) = value else { return [] }
    return values.enumerated().compactMap { index, value in
        guard case let .object(item) = value else { return nil }
        return RuntimeRow(id: StableID(item[key] ?? .number(Double(index))), item: item, index: index)
    }
}

private struct ShapeView: View {
    let kind: ShapeKind
    let radius: CGFloat?
    let paint: Paint
    let host: ScreenHost
    @ViewBuilder var body: some View {
        switch kind {
        case .rect: PaintView(paint: paint, host: host).clipShape(Rectangle())
        case .rounded: PaintView(paint: paint, host: host).clipShape(RoundedRectangle(cornerRadius: radius ?? 0))
        case .capsule: PaintView(paint: paint, host: host).clipShape(Capsule())
        case .circle: PaintView(paint: paint, host: host).clipShape(Circle())
        }
    }
}

private extension Optional where Wrapped == DocumentButtonRole {
    var swiftUI: SwiftUI.ButtonRole? {
        switch self { case .destructive: .destructive; case .cancel: .cancel; case nil: nil }
    }
}
