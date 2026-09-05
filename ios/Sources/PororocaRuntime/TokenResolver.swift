import SwiftUI
import PororocaDocument

@MainActor
public protocol TokenResolver {
    func color(named name: String) -> Color?
    func space(named name: String) -> CGFloat?
    func radius(named name: String) -> CGFloat?
    func font(named name: String) -> Font?
}

public struct DictionaryTokenResolver: TokenResolver {
    public var colors: [String: Color]
    public var spaces: [String: CGFloat]
    public var radii: [String: CGFloat]
    public var fonts: [String: Font]

    public init(
        colors: [String: Color] = [:],
        spaces: [String: CGFloat] = [:],
        radii: [String: CGFloat] = [:],
        fonts: [String: Font] = [:]
    ) {
        self.colors = colors
        self.spaces = spaces
        self.radii = radii
        self.fonts = fonts
    }

    public func color(named name: String) -> Color? { colors[name] }
    public func space(named name: String) -> CGFloat? { spaces[name] }
    public func radius(named name: String) -> CGFloat? { radii[name] }
    public func font(named name: String) -> Font? { fonts[name] }
}

extension TokenResolver {
    func resolve(_ value: Dim?) -> CGFloat? {
        switch value {
        case let .points(points): CGFloat(points)
        case let .token(name): space(named: name)
        case nil: nil
        }
    }

    func resolve(_ value: Radius?) -> CGFloat? {
        switch value {
        case let .points(points): CGFloat(points)
        case let .token(name): radius(named: name)
        case nil: nil
        }
    }

    func resolve(_ value: ColorValue) -> Color {
        switch value {
        case let .token(name, opacity):
            return (color(named: name) ?? .clear).opacity(opacity ?? 1)
        case let .hex(hex):
            return Color(hex: hex.rawValue)
        }
    }

    func resolve(_ value: FontValue) -> Font {
        switch value {
        case let .token(name): return font(named: name) ?? .body
        case let .system(system):
            return SwiftUI.Font.system(
                size: system.size,
                weight: (system.weight ?? .regular).swiftUI,
                design: system.design?.swiftUI ?? .default
            )
        }
    }
}

private extension Color {
    init(hex: String) {
        let value = UInt64(hex.dropFirst(), radix: 16) ?? 0
        let hasAlpha = hex.count == 9
        let red = Double((value >> (hasAlpha ? 24 : 16)) & 0xff) / 255
        let green = Double((value >> (hasAlpha ? 16 : 8)) & 0xff) / 255
        let blue = Double((value >> (hasAlpha ? 8 : 0)) & 0xff) / 255
        let alpha = hasAlpha ? Double(value & 0xff) / 255 : 1
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension DocumentFontWeight {
    var swiftUI: SwiftUI.Font.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

extension DocumentFontDesign {
    var swiftUI: SwiftUI.Font.Design {
        switch self {
        case .default: .default
        case .serif: .serif
        case .rounded: .rounded
        case .monospaced: .monospaced
        }
    }
}
