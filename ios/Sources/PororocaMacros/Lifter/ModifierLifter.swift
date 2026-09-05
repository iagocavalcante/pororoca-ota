import Foundation
import SwiftSyntax

struct ModifierLifter {
    let colors: String
    let spaces: String
    let radii: String
    let expr: ExprLifter

    func apply(name: String, arguments: String, to base: String) throws -> String {
        guard Whitelist.modifiers.contains(name) else {
            throw LiftFailure(diagnostic: .unsupportedModifier, node: Syntax(TokenSyntax.identifier(name)))
        }
        switch name {
        case "foregroundStyle": return "\(base).foreground(\(try color(arguments)))"
        case "background": return "\(base).background(.color(\(try color(arguments))))"
        case "opacity", "lineLimit", "minimumScaleFactor", "fixedSize", "disabled", "ignoresSafeArea":
            return "\(base).\(name)(\(arguments))"
        case "multilineTextAlignment": return "\(base).multilineAlignment(\(arguments))"
        case "padding":
            let parts = splitArguments(arguments)
            if parts.count == 1 { return "\(base).padding(.all, \(try dimension(parts[0])))" }
            let edge = parts[0].replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
            return "\(base).padding(\(edge), \(try dimension(parts[1])))"
        case "frame":
            return "\(base).frame(\(try frameArguments(arguments)))"
        case "font":
            if base.hasPrefix("PororocaDSL.Icon("), let icon = iconFont(arguments) { return "\(base).iconFont(\(icon))" }
            return "\(base).font(\(try font(arguments)))"
        case "clipShape":
            let text = arguments.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.hasPrefix("RoundedRectangle") {
                let inside = callArguments(text)
                let radiusArg = splitArguments(inside).first ?? "0"
                let value = radiusArg.replacingOccurrences(of: "cornerRadius:", with: "")
                return "\(base).cornerRadius(\(try radius(value)))"
            }
            if text.hasPrefix("Capsule") { return "\(base).clip(.capsule)" }
            if text.hasPrefix("Circle") { return "\(base).clip(.circle)" }
            throw LiftFailure(diagnostic: .unsupportedModifier, node: Syntax(TokenSyntax.identifier(name)))
        case "fill":
            if arguments.contains("LinearGradient") { return "\(base).fill(\(try gradient(arguments)))" }
            return "\(base).fill(.color(\(try color(arguments))))"
        case "tint": return "\(base).tint(\(try color(arguments)))"
        case "buttonStyle", "progressViewStyle", "defaultScrollAnchor": return base
        default: return base
        }
    }

    func color(_ source: String) throws -> String {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if let dot = text.range(of: ".opacity("), text.hasSuffix(")") {
            let base = String(text[..<dot.lowerBound])
            let opacity = String(text[dot.upperBound..<text.index(before: text.endIndex)])
            return "\(try color(base, opacity: opacity))"
        }
        return try color(text, opacity: nil)
    }

    private func color(_ source: String, opacity: String?) throws -> String {
        guard source.hasPrefix(colors + ".") else {
            throw LiftFailure(diagnostic: .unknownTokenNamespace, node: Syntax(TokenSyntax.identifier(source)))
        }
        let name = String(source.dropFirst(colors.count + 1))
        return ".color(\(quoted(name))\(opacity.map { ", opacity: \($0)" } ?? ""))"
    }

    func dimension(_ source: String) throws -> String {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix(spaces + ".") { return ".space(\(quoted(String(text.dropFirst(spaces.count + 1)))))" }
        if Double(text) != nil { return ".points(\(text))" }
        throw LiftFailure(diagnostic: .unknownTokenNamespace, node: Syntax(TokenSyntax.identifier(text)))
    }

    func radius(_ source: String) throws -> String {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix(radii + ".") { return ".radius(\(quoted(String(text.dropFirst(radii.count + 1)))))" }
        if Double(text) != nil { return ".points(\(text))" }
        throw LiftFailure(diagnostic: .unknownTokenNamespace, node: Syntax(TokenSyntax.identifier(text)))
    }

    private func frameArguments(_ source: String) throws -> String {
        splitArguments(source).map { part in
            let bits = part.split(separator: ":", maxSplits: 1).map(String.init)
            guard bits.count == 2 else { return part }
            let label = bits[0].trimmingCharacters(in: .whitespaces)
            let raw = bits[1].trimmingCharacters(in: .whitespaces)
            let value: String
            if label == "alignment" { value = raw }
            else { value = raw == ".infinity" ? ".infinity" : ".points(\(raw))" }
            return "\(label): \(value)"
        }.joined(separator: ", ")
    }

    private func font(_ source: String) throws -> String {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix(".system(") || text.hasPrefix("Font.system(") else {
            throw LiftFailure(diagnostic: .unsupportedModifier, node: Syntax(TokenSyntax.identifier("font")))
        }
        return ".system(\(callArguments(text)))"
    }

    private func iconFont(_ source: String) -> String? {
        let inside = callArguments(source)
        let parts = splitArguments(inside)
        guard let sizePart = parts.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("size:") }) else { return nil }
        let size = sizePart.split(separator: ":", maxSplits: 1).last.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? "0"
        let weight = parts.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("weight:") })?.split(separator: ":", maxSplits: 1).last.map(String.init)?.trimmingCharacters(in: .whitespaces)
        return "size: \(size)" + (weight.map { ", weight: \($0)" } ?? "")
    }

    private func gradient(_ source: String) throws -> String {
        let inside = callArguments(source)
        let parts = splitArguments(inside)
        guard parts.count >= 3 else { throw LiftFailure(diagnostic: .unsupportedModifier, node: Syntax(TokenSyntax.identifier("LinearGradient"))) }
        let colorsPart = parts[0].split(separator: ":", maxSplits: 1).last.map(String.init) ?? "[]"
        let innerColors = colorsPart.trimmingCharacters(in: CharacterSet(charactersIn: " []"))
        let liftedColors = try splitArguments(innerColors).map(color).joined(separator: ", ")
        let start = parts[1].split(separator: ":", maxSplits: 1).last.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ".top"
        let end = parts[2].split(separator: ":", maxSplits: 1).last.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ".bottom"
        return ".gradient(.linear(.init(colors: [\(liftedColors)], start: \(start), end: \(end))))"
    }
}

func splitArguments(_ source: String) -> [String] { splitTopLevel(source, separator: ",") }

func callArguments(_ source: String) -> String {
    guard let open = source.firstIndex(of: "("),
          source[..<open].allSatisfy({ $0 != "{" }),
          let close = matchingDelimiter(in: source, from: open, open: "(", close: ")") else { return "" }
    return String(source[source.index(after: open)..<close])
}
