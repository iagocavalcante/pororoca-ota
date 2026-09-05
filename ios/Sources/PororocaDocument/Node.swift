import PororocaExpr

/// The wire name of every Phase 0 node kind.
public enum NodeKindName: String, Sendable, CaseIterable, Codable {
    case vstack, hstack, zstack, box, spacer, scroll, lazycolumn, text, icon, image, shape, divider, progress, button, `if`, foreach, slot
    public init(from decoder: Decoder) throws { self = try decodeStringEnum(Self.self, from: decoder) }
}

/// A node in a Pororoca screen document.
public struct Node: Sendable, Equatable, Codable {
    public var kind: Kind
    public var mod: ModifierProps?

    public init(_ kind: Kind, mod: ModifierProps? = nil) { self.kind = kind; self.mod = mod?.isEmpty == true ? nil : mod }

    /// A strongly typed node payload.
    public indirect enum Kind: Sendable, Equatable {
        case vstack(spacing: Dim?, alignment: HorizontalAlignment?, children: [Node])
        case hstack(spacing: Dim?, alignment: VerticalAlignment?, children: [Node])
        case zstack(alignment: Alignment?, children: [Node])
        case box(child: Node)
        case spacer(minLength: Dim?)
        case scroll(axis: Axis?, child: Node)
        case lazycolumn(spacing: Dim?, children: [Node])
        case text(value: Str)
        case icon(sf: String, material: String?, size: Double?, weight: FontWeight?)
        case image(source: ImageSource, contentMode: ContentMode?)
        case shape(kind: ShapeKind, cornerRadius: Radius?, fill: Paint?)
        case divider
        case progress(tint: ColorValue?)
        case button(action: Action, role: ButtonRole?, label: Node)
        case `if`(cond: Expr, then: Node, else: Node?)
        case foreach(items: Expr, key: String, template: Node)
        case slot(name: String, props: [String: SlotProp])

        public var name: NodeKindName {
            switch self { case .vstack: .vstack; case .hstack: .hstack; case .zstack: .zstack; case .box: .box; case .spacer: .spacer; case .scroll: .scroll; case .lazycolumn: .lazycolumn; case .text: .text; case .icon: .icon; case .image: .image; case .shape: .shape; case .divider: .divider; case .progress: .progress; case .button: .button; case .if: .if; case .foreach: .foreach; case .slot: .slot }
        }
    }

    public var children: [Node] {
        switch kind { case let .vstack(_, _, c), let .hstack(_, _, c), let .zstack(_, c), let .lazycolumn(_, c): c; case let .box(c), let .scroll(_, c), let .button(_, _, c): [c]; case let .if(_, thenNode, elseNode): [thenNode] + (elseNode.map { [$0] } ?? []); case let .foreach(_, _, template): [template]; default: [] }
    }

    enum CodingKeys: String, CodingKey, CaseIterable { case type = "t", props = "p", mod, children = "c" }

    public init(from decoder: Decoder) throws {
        let c = try decoder.strictContainer(keyedBy: CodingKeys.self)
        let rawKind = try c.decode(String.self, forKey: .type)
        guard let name = NodeKindName(rawValue: rawKind) else { throw DocumentCodecError(code: .unknownKind, path: JSONPath(codingPath: decoder.codingPath), detail: rawKind) }
        let hasChildren = c.contains(.children)
        let path = JSONPath(codingPath: decoder.codingPath)
        func childArray() throws -> [Node] { try c.decodeIfPresent([Node].self, forKey: .children) ?? [] }
        func oneChild(_ kind: String) throws -> Node {
            let decodedChildren = try childArray()
            guard decodedChildren.count == 1, let child = decodedChildren.first else { throw DocumentCodecError(code: .childCount, path: path, detail: "\(kind) expected 1 child, got \(decodedChildren.count)") }
            return child
        }
        func rejectChildren(_ kind: String) throws {
            if hasChildren { throw DocumentCodecError(code: .unexpectedChildren, path: path, detail: "\(kind) does not accept children") }
        }

        switch name {
        case .vstack:
            let p = try c.decodeIfPresent(VStackProps.self, forKey: .props) ?? .init(); kind = .vstack(spacing: p.spacing, alignment: p.alignment, children: try childArray())
        case .hstack:
            let p = try c.decodeIfPresent(HStackProps.self, forKey: .props) ?? .init(); kind = .hstack(spacing: p.spacing, alignment: p.alignment, children: try childArray())
        case .zstack:
            let p = try c.decodeIfPresent(ZStackProps.self, forKey: .props) ?? .init(); kind = .zstack(alignment: p.alignment, children: try childArray())
        case .box:
            _ = try c.decodeIfPresent(EmptyProps.self, forKey: .props); kind = .box(child: try oneChild("box"))
        case .spacer:
            try rejectChildren("spacer"); let p = try c.decodeIfPresent(SpacerProps.self, forKey: .props) ?? .init(); kind = .spacer(minLength: p.minLength)
        case .scroll:
            let p = try c.decodeIfPresent(ScrollProps.self, forKey: .props) ?? .init(); kind = .scroll(axis: p.axis, child: try oneChild("scroll"))
        case .lazycolumn:
            let p = try c.decodeIfPresent(LazyProps.self, forKey: .props) ?? .init(); kind = .lazycolumn(spacing: p.spacing, children: try childArray())
        case .text:
            try rejectChildren("text"); let p = try c.decode(TextProps.self, forKey: .props); kind = .text(value: p.value)
        case .icon:
            try rejectChildren("icon"); let p = try c.decode(IconProps.self, forKey: .props); kind = .icon(sf: p.sf, material: p.material, size: p.size, weight: p.weight)
        case .image:
            try rejectChildren("image"); let p = try c.decode(ImageProps.self, forKey: .props); kind = .image(source: p.source, contentMode: p.contentMode)
        case .shape:
            try rejectChildren("shape"); let p = try c.decode(ShapeProps.self, forKey: .props); kind = .shape(kind: p.kind, cornerRadius: p.cornerRadius, fill: p.fill)
        case .divider:
            try rejectChildren("divider"); _ = try c.decodeIfPresent(EmptyProps.self, forKey: .props); kind = .divider
        case .progress:
            try rejectChildren("progress"); let p = try c.decodeIfPresent(ProgressProps.self, forKey: .props) ?? .init(); kind = .progress(tint: p.tint)
        case .button:
            let p = try c.decode(ButtonProps.self, forKey: .props); kind = .button(action: p.action, role: p.role, label: try oneChild("button"))
        case .if:
            try rejectChildren("if"); let p = try c.decode(IfProps.self, forKey: .props); kind = .if(cond: p.cond, then: p.then, else: p.else)
        case .foreach:
            try rejectChildren("foreach"); let p = try c.decode(ForEachProps.self, forKey: .props); kind = .foreach(items: p.items, key: p.key, template: p.template)
        case .slot:
            try rejectChildren("slot"); let p = try c.decode(SlotProps.self, forKey: .props); kind = .slot(name: p.name, props: p.props)
        }
        let decodedMod = try c.decodeIfPresent(ModifierProps.self, forKey: .mod)
        mod = decodedMod?.isEmpty == true ? nil : decodedMod
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind.name.rawValue, forKey: .type)
        if let mod, !mod.isEmpty { try c.encode(mod, forKey: .mod) }
        switch kind {
        case let .vstack(spacing, alignment, children): let p = VStackProps(spacing: spacing, alignment: alignment); if !p.isEmpty { try c.encode(p, forKey: .props) }; if !children.isEmpty { try c.encode(children, forKey: .children) }
        case let .hstack(spacing, alignment, children): let p = HStackProps(spacing: spacing, alignment: alignment); if !p.isEmpty { try c.encode(p, forKey: .props) }; if !children.isEmpty { try c.encode(children, forKey: .children) }
        case let .zstack(alignment, children): let p = ZStackProps(alignment: alignment); if !p.isEmpty { try c.encode(p, forKey: .props) }; if !children.isEmpty { try c.encode(children, forKey: .children) }
        case let .box(child): try c.encode([child], forKey: .children)
        case let .spacer(minLength): if minLength != nil { try c.encode(SpacerProps(minLength: minLength), forKey: .props) }
        case let .scroll(axis, child): if axis != nil { try c.encode(ScrollProps(axis: axis), forKey: .props) }; try c.encode([child], forKey: .children)
        case let .lazycolumn(spacing, children): if spacing != nil { try c.encode(LazyProps(spacing: spacing), forKey: .props) }; if !children.isEmpty { try c.encode(children, forKey: .children) }
        case let .text(value): try c.encode(TextProps(value: value), forKey: .props)
        case let .icon(sf, material, size, weight): try c.encode(IconProps(sf: sf, material: material, size: size, weight: weight), forKey: .props)
        case let .image(source, contentMode): try c.encode(ImageProps(source: source, contentMode: contentMode), forKey: .props)
        case let .shape(shapeKind, cornerRadius, fill): try c.encode(ShapeProps(kind: shapeKind, cornerRadius: cornerRadius, fill: fill), forKey: .props)
        case .divider: break
        case let .progress(tint): if tint != nil { try c.encode(ProgressProps(tint: tint), forKey: .props) }
        case let .button(action, role, label): try c.encode(ButtonProps(action: action, role: role), forKey: .props); try c.encode([label], forKey: .children)
        case let .if(cond, thenNode, elseNode): try c.encode(IfProps(cond: cond, then: thenNode, else: elseNode), forKey: .props)
        case let .foreach(items, key, template): try c.encode(ForEachProps(items: items, key: key, template: template), forKey: .props)
        case let .slot(name, props): try c.encode(SlotProps(name: name, props: props), forKey: .props)
        }
    }
}

private struct EmptyProps: Codable { enum CodingKeys: CodingKey, CaseIterable {}; init() {}; init(from decoder: Decoder) throws { _ = try decoder.strictContainer(keyedBy: CodingKeys.self) } }
private struct VStackProps: Codable { var spacing: Dim?; var alignment: HorizontalAlignment?; var isEmpty: Bool { spacing == nil && alignment == nil }; init(spacing: Dim? = nil, alignment: HorizontalAlignment? = nil) { self.spacing = spacing; self.alignment = alignment }; enum CodingKeys: String, CodingKey, CaseIterable { case spacing, alignment }; init(from d: Decoder) throws { let c = try d.strictContainer(keyedBy: CodingKeys.self); spacing = try c.decodeIfPresent(Dim.self, forKey: .spacing); alignment = try c.decodeIfPresent(HorizontalAlignment.self, forKey: .alignment) } }
private struct HStackProps: Codable { var spacing: Dim?; var alignment: VerticalAlignment?; var isEmpty: Bool { spacing == nil && alignment == nil }; init(spacing: Dim? = nil, alignment: VerticalAlignment? = nil) { self.spacing = spacing; self.alignment = alignment }; enum CodingKeys: String, CodingKey, CaseIterable { case spacing, alignment }; init(from d: Decoder) throws { let c = try d.strictContainer(keyedBy: CodingKeys.self); spacing = try c.decodeIfPresent(Dim.self, forKey: .spacing); alignment = try c.decodeIfPresent(VerticalAlignment.self, forKey: .alignment) } }
private struct ZStackProps: Codable { var alignment: Alignment?; var isEmpty: Bool { alignment == nil }; init(alignment: Alignment? = nil) { self.alignment = alignment }; enum CodingKeys: String, CodingKey, CaseIterable { case alignment }; init(from d: Decoder) throws { alignment = try d.strictContainer(keyedBy: CodingKeys.self).decodeIfPresent(Alignment.self, forKey: .alignment) } }
private struct SpacerProps: Codable { var minLength: Dim?; init(minLength: Dim? = nil) { self.minLength = minLength }; enum CodingKeys: String, CodingKey, CaseIterable { case minLength }; init(from d: Decoder) throws { minLength = try d.strictContainer(keyedBy: CodingKeys.self).decodeIfPresent(Dim.self, forKey: .minLength) } }
private struct ScrollProps: Codable { var axis: Axis?; init(axis: Axis? = nil) { self.axis = axis }; enum CodingKeys: String, CodingKey, CaseIterable { case axis }; init(from d: Decoder) throws { axis = try d.strictContainer(keyedBy: CodingKeys.self).decodeIfPresent(Axis.self, forKey: .axis) } }
private struct LazyProps: Codable { var spacing: Dim?; init(spacing: Dim? = nil) { self.spacing = spacing }; enum CodingKeys: String, CodingKey, CaseIterable { case spacing }; init(from d: Decoder) throws { spacing = try d.strictContainer(keyedBy: CodingKeys.self).decodeIfPresent(Dim.self, forKey: .spacing) } }
private struct TextProps: Codable { var value: Str; enum CodingKeys: String, CodingKey, CaseIterable { case value }; init(value: Str) { self.value = value }; init(from d: Decoder) throws { value = try d.strictContainer(keyedBy: CodingKeys.self).decode(Str.self, forKey: .value) } }
private struct IconProps: Codable { var sf: String; var material: String?; var size: Double?; var weight: FontWeight?; enum CodingKeys: String, CodingKey, CaseIterable { case sf, material, size, weight }; init(sf: String, material: String?, size: Double?, weight: FontWeight?) { self.sf = sf; self.material = material; self.size = size; self.weight = weight }; init(from d: Decoder) throws { let c = try d.strictContainer(keyedBy: CodingKeys.self); sf = try c.decode(String.self, forKey: .sf); material = try c.decodeIfPresent(String.self, forKey: .material); size = try c.decodeIfPresent(Double.self, forKey: .size); weight = try c.decodeIfPresent(FontWeight.self, forKey: .weight) } }
private struct ImageProps: Codable { var source: ImageSource; var contentMode: ContentMode?; enum CodingKeys: String, CodingKey, CaseIterable { case source, contentMode }; init(source: ImageSource, contentMode: ContentMode?) { self.source = source; self.contentMode = contentMode }; init(from d: Decoder) throws { let c = try d.strictContainer(keyedBy: CodingKeys.self); source = try c.decode(ImageSource.self, forKey: .source); contentMode = try c.decodeIfPresent(ContentMode.self, forKey: .contentMode) } }
private struct ShapeProps: Codable { var kind: ShapeKind; var cornerRadius: Radius?; var fill: Paint?; enum CodingKeys: String, CodingKey, CaseIterable { case kind, cornerRadius, fill }; init(kind: ShapeKind, cornerRadius: Radius?, fill: Paint?) { self.kind = kind; self.cornerRadius = cornerRadius; self.fill = fill }; init(from d: Decoder) throws { let c = try d.strictContainer(keyedBy: CodingKeys.self); kind = try c.decode(ShapeKind.self, forKey: .kind); cornerRadius = try c.decodeIfPresent(Radius.self, forKey: .cornerRadius); fill = try c.decodeIfPresent(Paint.self, forKey: .fill) } }
private struct ProgressProps: Codable { var tint: ColorValue?; init(tint: ColorValue? = nil) { self.tint = tint }; enum CodingKeys: String, CodingKey, CaseIterable { case tint }; init(from d: Decoder) throws { tint = try d.strictContainer(keyedBy: CodingKeys.self).decodeIfPresent(ColorValue.self, forKey: .tint) } }
private struct ButtonProps: Codable { var action: Action; var role: ButtonRole?; enum CodingKeys: String, CodingKey, CaseIterable { case action, role }; init(action: Action, role: ButtonRole?) { self.action = action; self.role = role }; init(from d: Decoder) throws { let c = try d.strictContainer(keyedBy: CodingKeys.self); action = try c.decode(Action.self, forKey: .action); role = try c.decodeIfPresent(ButtonRole.self, forKey: .role) } }
private struct IfProps: Codable { var cond: Expr; var then: Node; var `else`: Node?; enum CodingKeys: String, CodingKey, CaseIterable { case cond, then, `else` }; init(cond: Expr, then: Node, else: Node?) { self.cond = cond; self.then = then; self.else = `else` }; init(from d: Decoder) throws { let c = try d.strictContainer(keyedBy: CodingKeys.self); cond = try c.decode(Expr.self, forKey: .cond); then = try c.decode(Node.self, forKey: .then); `else` = try c.decodeIfPresent(Node.self, forKey: .else) } }
private struct ForEachProps: Codable { var items: Expr; var key: String; var template: Node; enum CodingKeys: String, CodingKey, CaseIterable { case items, key, template }; init(items: Expr, key: String, template: Node) { self.items = items; self.key = key; self.template = template }; init(from d: Decoder) throws { let c = try d.strictContainer(keyedBy: CodingKeys.self); items = try c.decode(Expr.self, forKey: .items); key = try c.decode(String.self, forKey: .key); template = try c.decode(Node.self, forKey: .template) } }
private struct SlotProps: Codable { var name: String; var props: [String: SlotProp]; enum CodingKeys: String, CodingKey, CaseIterable { case name, props }; init(name: String, props: [String: SlotProp]) { self.name = name; self.props = props }; init(from d: Decoder) throws { let c = try d.strictContainer(keyedBy: CodingKeys.self); name = try c.decode(String.self, forKey: .name); props = try c.decodeIfPresent([String: SlotProp].self, forKey: .props) ?? [:] }; func encode(to e: Encoder) throws { var c = e.container(keyedBy: CodingKeys.self); try c.encode(name, forKey: .name); if !props.isEmpty { try c.encode(props, forKey: .props) } } }
