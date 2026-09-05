import PororocaDocument

/// One ordered modifier application awaiting canonicalisation.
public enum ModifierApplication: Sendable, Equatable {
    case font(FontValue), foreground(ColorValue), lineLimit(Int), multilineAlignment(TextAlignment)
    case minimumScaleFactor(Double), fixedSize(FixedSize), padding(Padding), background(Paint), frame(Frame)
    case cornerRadius(CornerRadius), clip(ClipShape), border(Border), shadow(Shadow), opacity(Double)
    case disabled(Expr), hidden(Expr), accessibilityLabel(Str), ignoresSafeArea(Edges), id(String)

    public var key: ModifierKey {
        switch self { case .font: .font; case .foreground: .foreground; case .lineLimit: .lineLimit; case .multilineAlignment: .multilineAlignment; case .minimumScaleFactor: .minimumScaleFactor; case .fixedSize: .fixedSize; case .padding: .padding; case .background: .background; case .frame: .frame; case .cornerRadius: .cornerRadius; case .clip: .clip; case .border: .border; case .shadow: .shadow; case .opacity: .opacity; case .disabled: .disabled; case .hidden: .hidden; case .accessibilityLabel: .accessibilityLabel; case .ignoresSafeArea: .ignoresSafeArea; case .id: .id }
    }

    func apply(to props: inout ModifierProps) {
        switch self { case let .font(v): props.font = v; case let .foreground(v): props.foreground = v; case let .lineLimit(v): props.lineLimit = v; case let .multilineAlignment(v): props.multilineAlignment = v; case let .minimumScaleFactor(v): props.minimumScaleFactor = v; case let .fixedSize(v): props.fixedSize = v; case let .padding(v): props.padding.append(v); case let .background(v): props.background = v; case let .frame(v): props.frame = v; case let .cornerRadius(v): props.cornerRadius = v; case let .clip(v): props.clip = v; case let .border(v): props.border = v; case let .shadow(v): props.shadow = v; case let .opacity(v): props.opacity = v; case let .disabled(v): props.disabled = v; case let .hidden(v): props.hidden = v; case let .accessibilityLabel(v): props.accessibilityLabel = v; case let .ignoresSafeArea(v): props.ignoresSafeArea = v; case let .id(v): props.id = v }
    }
}

/// Shared canonical modifier resolution used by the DSL and macro lifter.
public enum Canonicalizer {
    public static func apply(_ applications: [ModifierApplication], to node: Node) -> Node {
        var current = node
        for application in applications {
            var props = current.mod ?? .init()
            let overlaps = application.key == .padding && {
                guard case let .padding(newPadding) = application else { return false }
                return props.padding.contains { $0.edges.overlaps(newPadding.edges) }
            }()
            let isCanonical = !overlaps && (props.highestRankSet.map { application.key.rank >= $0.rank } ?? true)
            if isCanonical {
                application.apply(to: &props)
                current.mod = props
            } else {
                var wrapperProps = ModifierProps()
                application.apply(to: &wrapperProps)
                current = Node(.box(child: current), mod: wrapperProps)
            }
        }
        return current
    }
}
