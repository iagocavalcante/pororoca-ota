import PororocaExpr

/// Modifier keys ordered from inside to outside.
public enum ModifierKey: String, Sendable, CaseIterable {
    case font, foreground, lineLimit, multilineAlignment, minimumScaleFactor, fixedSize, padding, background, frame, cornerRadius, clip, border, shadow, opacity, disabled, hidden, accessibilityLabel, ignoresSafeArea, id
    public var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}
/// A padding modifier.
public struct Padding: Sendable, Equatable, Codable {
    public var edges: Edges; public var value: Dim
    public init(edges: Edges, value: Dim) { self.edges = edges; self.value = value }
    enum CodingKeys: String, CodingKey, CaseIterable { case edges, value }
    public init(from decoder: Decoder) throws { let c = try decoder.strictContainer(keyedBy: CodingKeys.self); edges = try c.decode(Edges.self, forKey: .edges); value = try c.decode(Dim.self, forKey: .value) }
}
/// A fixed-size modifier.
public struct FixedSize: Sendable, Equatable, Codable {
    public var horizontal: Bool; public var vertical: Bool
    public init(horizontal: Bool, vertical: Bool) { self.horizontal = horizontal; self.vertical = vertical }
    enum CodingKeys: String, CodingKey, CaseIterable { case horizontal, vertical }
    public init(from decoder: Decoder) throws { let c = try decoder.strictContainer(keyedBy: CodingKeys.self); horizontal = try c.decode(Bool.self, forKey: .horizontal); vertical = try c.decode(Bool.self, forKey: .vertical) }
}
/// A frame modifier.
public struct Frame: Sendable, Equatable, Codable {
    public var width, height, minWidth, maxWidth, minHeight, maxHeight: FrameDimension?
    public var alignment: Alignment?
    public init(width: FrameDimension? = nil, height: FrameDimension? = nil, minWidth: FrameDimension? = nil, maxWidth: FrameDimension? = nil, minHeight: FrameDimension? = nil, maxHeight: FrameDimension? = nil, alignment: Alignment? = nil) { self.width = width; self.height = height; self.minWidth = minWidth; self.maxWidth = maxWidth; self.minHeight = minHeight; self.maxHeight = maxHeight; self.alignment = alignment }
    enum CodingKeys: String, CodingKey, CaseIterable { case width, height, minWidth, maxWidth, minHeight, maxHeight, alignment }
    public init(from decoder: Decoder) throws { let c = try decoder.strictContainer(keyedBy: CodingKeys.self); width = try c.decodeIfPresent(FrameDimension.self, forKey: .width); height = try c.decodeIfPresent(FrameDimension.self, forKey: .height); minWidth = try c.decodeIfPresent(FrameDimension.self, forKey: .minWidth); maxWidth = try c.decodeIfPresent(FrameDimension.self, forKey: .maxWidth); minHeight = try c.decodeIfPresent(FrameDimension.self, forKey: .minHeight); maxHeight = try c.decodeIfPresent(FrameDimension.self, forKey: .maxHeight); alignment = try c.decodeIfPresent(Alignment.self, forKey: .alignment) }
}
/// A corner-radius modifier.
public struct CornerRadius: Sendable, Equatable, Codable {
    public var radius: Radius; public var style: CornerStyle
    public init(radius: Radius, style: CornerStyle) { self.radius = radius; self.style = style }
    enum CodingKeys: String, CodingKey, CaseIterable { case radius, style }
    public init(from decoder: Decoder) throws { let c = try decoder.strictContainer(keyedBy: CodingKeys.self); radius = try c.decode(Radius.self, forKey: .radius); style = try c.decode(CornerStyle.self, forKey: .style) }
}
/// A border modifier.
public struct Border: Sendable, Equatable, Codable {
    public var color: ColorValue; public var width: Double
    public init(color: ColorValue, width: Double) { self.color = color; self.width = width }
    enum CodingKeys: String, CodingKey, CaseIterable { case color, width }
    public init(from decoder: Decoder) throws { let c = try decoder.strictContainer(keyedBy: CodingKeys.self); color = try c.decode(ColorValue.self, forKey: .color); width = try c.decode(Double.self, forKey: .width) }
}
/// A shadow modifier.
public struct Shadow: Sendable, Equatable, Codable {
    public var color: ColorValue; public var radius: Double; public var x: Double; public var y: Double
    public init(color: ColorValue, radius: Double, x: Double, y: Double) { self.color = color; self.radius = radius; self.x = x; self.y = y }
    enum CodingKeys: String, CodingKey, CaseIterable { case color, radius, x, y }
    public init(from decoder: Decoder) throws { let c = try decoder.strictContainer(keyedBy: CodingKeys.self); color = try c.decode(ColorValue.self, forKey: .color); radius = try c.decode(Double.self, forKey: .radius); x = try c.decode(Double.self, forKey: .x); y = try c.decode(Double.self, forKey: .y) }
}

/// The complete Phase 0 modifier set.
public struct ModifierProps: Sendable, Equatable, Codable {
    public var font: FontValue?; public var foreground: ColorValue?; public var lineLimit: Int?; public var multilineAlignment: TextAlignment?; public var minimumScaleFactor: Double?; public var fixedSize: FixedSize?; public var padding: [Padding]; public var background: Paint?; public var frame: Frame?; public var cornerRadius: CornerRadius?; public var clip: ClipShape?; public var border: Border?; public var shadow: Shadow?; public var opacity: Double?; public var disabled: Expr?; public var hidden: Expr?; public var accessibilityLabel: Str?; public var ignoresSafeArea: Edges?; public var id: String?
    public init(font: FontValue? = nil, foreground: ColorValue? = nil, lineLimit: Int? = nil, multilineAlignment: TextAlignment? = nil, minimumScaleFactor: Double? = nil, fixedSize: FixedSize? = nil, padding: [Padding] = [], background: Paint? = nil, frame: Frame? = nil, cornerRadius: CornerRadius? = nil, clip: ClipShape? = nil, border: Border? = nil, shadow: Shadow? = nil, opacity: Double? = nil, disabled: Expr? = nil, hidden: Expr? = nil, accessibilityLabel: Str? = nil, ignoresSafeArea: Edges? = nil, id: String? = nil) { self.font = font; self.foreground = foreground; self.lineLimit = lineLimit; self.multilineAlignment = multilineAlignment; self.minimumScaleFactor = minimumScaleFactor; self.fixedSize = fixedSize; self.padding = padding; self.background = background; self.frame = frame; self.cornerRadius = cornerRadius; self.clip = clip; self.border = border; self.shadow = shadow; self.opacity = opacity; self.disabled = disabled; self.hidden = hidden; self.accessibilityLabel = accessibilityLabel; self.ignoresSafeArea = ignoresSafeArea; self.id = id }
    enum CodingKeys: String, CodingKey, CaseIterable { case font, foreground, lineLimit, multilineAlignment, minimumScaleFactor, fixedSize, padding, background, frame, cornerRadius, clip, border, shadow, opacity, disabled, hidden, accessibilityLabel, ignoresSafeArea, id }
    public init(from decoder: Decoder) throws {
        let c = try decoder.strictContainer(keyedBy: CodingKeys.self); font = try c.decodeIfPresent(FontValue.self, forKey: .font); foreground = try c.decodeIfPresent(ColorValue.self, forKey: .foreground); lineLimit = try c.decodeIfPresent(Int.self, forKey: .lineLimit); multilineAlignment = try c.decodeIfPresent(TextAlignment.self, forKey: .multilineAlignment); minimumScaleFactor = try c.decodeIfPresent(Double.self, forKey: .minimumScaleFactor); fixedSize = try c.decodeIfPresent(FixedSize.self, forKey: .fixedSize)
        if c.contains(.padding) {
            let paddingDecoder = try c.superDecoder(forKey: .padding)
            if var array = try? paddingDecoder.unkeyedContainer() {
                var values: [Padding] = []
                while !array.isAtEnd { values.append(try array.decode(Padding.self)) }
                padding = values
            } else {
                padding = [try Padding(from: paddingDecoder)]
            }
        } else { padding = [] }
        background = try c.decodeIfPresent(Paint.self, forKey: .background); frame = try c.decodeIfPresent(Frame.self, forKey: .frame); cornerRadius = try c.decodeIfPresent(CornerRadius.self, forKey: .cornerRadius); clip = try c.decodeIfPresent(ClipShape.self, forKey: .clip); border = try c.decodeIfPresent(Border.self, forKey: .border); shadow = try c.decodeIfPresent(Shadow.self, forKey: .shadow); opacity = try c.decodeIfPresent(Double.self, forKey: .opacity); disabled = try c.decodeIfPresent(Expr.self, forKey: .disabled); hidden = try c.decodeIfPresent(Expr.self, forKey: .hidden); accessibilityLabel = try c.decodeIfPresent(Str.self, forKey: .accessibilityLabel); ignoresSafeArea = try c.decodeIfPresent(Edges.self, forKey: .ignoresSafeArea); id = try c.decodeIfPresent(String.self, forKey: .id)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self); try c.encodeIfPresent(font, forKey: .font); try c.encodeIfPresent(foreground, forKey: .foreground); try c.encodeIfPresent(lineLimit, forKey: .lineLimit); try c.encodeIfPresent(multilineAlignment, forKey: .multilineAlignment); try c.encodeIfPresent(minimumScaleFactor, forKey: .minimumScaleFactor); try c.encodeIfPresent(fixedSize, forKey: .fixedSize); if padding.count == 1 { try c.encode(padding[0], forKey: .padding) } else if !padding.isEmpty { try c.encode(padding, forKey: .padding) }; try c.encodeIfPresent(background, forKey: .background); try c.encodeIfPresent(frame, forKey: .frame); try c.encodeIfPresent(cornerRadius, forKey: .cornerRadius); try c.encodeIfPresent(clip, forKey: .clip); try c.encodeIfPresent(border, forKey: .border); try c.encodeIfPresent(shadow, forKey: .shadow); try c.encodeIfPresent(opacity, forKey: .opacity); try c.encodeIfPresent(disabled, forKey: .disabled); try c.encodeIfPresent(hidden, forKey: .hidden); try c.encodeIfPresent(accessibilityLabel, forKey: .accessibilityLabel); try c.encodeIfPresent(ignoresSafeArea, forKey: .ignoresSafeArea); try c.encodeIfPresent(id, forKey: .id)
    }
    public var isEmpty: Bool { setKeys.isEmpty }
    public var setKeys: [ModifierKey] { ModifierKey.allCases.filter(isSet) }
    public var highestRankSet: ModifierKey? { setKeys.last }
    public func isSet(_ key: ModifierKey) -> Bool { switch key { case .font: font != nil; case .foreground: foreground != nil; case .lineLimit: lineLimit != nil; case .multilineAlignment: multilineAlignment != nil; case .minimumScaleFactor: minimumScaleFactor != nil; case .fixedSize: fixedSize != nil; case .padding: !padding.isEmpty; case .background: background != nil; case .frame: frame != nil; case .cornerRadius: cornerRadius != nil; case .clip: clip != nil; case .border: border != nil; case .shadow: shadow != nil; case .opacity: opacity != nil; case .disabled: disabled != nil; case .hidden: hidden != nil; case .accessibilityLabel: accessibilityLabel != nil; case .ignoresSafeArea: ignoresSafeArea != nil; case .id: id != nil } }
}
