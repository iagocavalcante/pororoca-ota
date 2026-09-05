import Foundation
import SwiftSyntax

struct ExprLifter {
    let stateNames: Set<String>
    let stringsPath: String

    func condition(_ source: String) throws -> String {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        for op in ["==", "!=", ">=", "<=", ">", "<"] {
            if let range = text.range(of: op) {
                return "\(try value(String(text[..<range.lowerBound]))) \(op) \(try literal(String(text[range.upperBound...])))"
            }
        }
        if text.hasPrefix("!") { return "!\(try value(String(text.dropFirst())))" }
        return try value(text)
    }

    func textArgument(_ source: String) throws -> String {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if isLocalizer(text), let key = firstStringLiteral(in: text) {
            return "Str.localized(\(quoted(key)))"
        }
        if text.hasPrefix("\"") && text.hasSuffix("\"") && text.contains("\\(") {
            return try interpolated(text)
        }
        if stateNames.contains(text) { return "state.\(text)" }
        if let range = text.range(of: "??") {
            let left = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let right = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if stateNames.contains(left) { return "Expr.coalesce([.state(\(quoted(left))), .literal(.string(\(right)))])" }
        }
        if text.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            throw LiftFailure(diagnostic: .notOTAState, node: Syntax(TokenSyntax.identifier(text)))
        }
        return text
    }

    func value(_ source: String) throws -> String {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let bare = text.hasPrefix("self.") ? String(text.dropFirst(5)) : text
        if stateNames.contains(bare) { return "state.\(bare)" }
        if text == "true" || text == "false" || text == "nil" || Double(text) != nil || text.hasPrefix("\"") {
            return text
        }
        throw LiftFailure(diagnostic: .notOTAState, node: Syntax(TokenSyntax.identifier(text)))
    }

    func literal(_ source: String) throws -> String { try value(source) }

    private func isLocalizer(_ text: String) -> Bool {
        text.hasPrefix(stringsPath + "(") || text.hasPrefix(stringsPath + ".")
    }

    private func interpolated(_ source: String) throws -> String {
        let body = String(source.dropFirst().dropLast())
        var components: [String] = []
        var literal = ""
        var index = body.startIndex
        while index < body.endIndex {
            if body[index] == "\\", body.index(after: index) < body.endIndex,
               body[body.index(after: index)] == "(" {
                if !literal.isEmpty { components.append(".literal(.string(\(quoted(literal))))"); literal = "" }
                let open = body.index(after: index)
                guard let close = matchingDelimiter(in: body, from: open, open: "(", close: ")") else { break }
                let raw = String(body[body.index(after: open)..<close]).trimmingCharacters(in: .whitespacesAndNewlines)
                if isLocalizer(raw), let key = firstStringLiteral(in: raw) {
                    components.append(".localized(\(quoted(key)))")
                } else if let coalesce = raw.range(of: "??") {
                    let left = String(raw[..<coalesce.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let right = String(raw[coalesce.upperBound...]).trimmingCharacters(in: .whitespaces)
                    let name = left.replacingOccurrences(of: "self.", with: "")
                    guard stateNames.contains(name) else { throw LiftFailure(diagnostic: .notOTAState, node: Syntax(TokenSyntax.identifier(name))) }
                    components.append(".coalesce([.state(\(quoted(name))), .literal(.string(\(right)))])")
                } else {
                    let name = raw.replacingOccurrences(of: "self.", with: "")
                    guard stateNames.contains(name) else { throw LiftFailure(diagnostic: .notOTAState, node: Syntax(TokenSyntax.identifier(name))) }
                    components.append(".state(\(quoted(name)))")
                }
                index = body.index(after: close)
            } else {
                literal.append(body[index])
                index = body.index(after: index)
            }
        }
        if !literal.isEmpty { components.append(".literal(.string(\(quoted(literal))))") }
        return "Str.expr(.concat([\(components.joined(separator: ", "))]))"
    }
}

func quoted(_ value: String) -> String {
    "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
}

func firstStringLiteral(in source: String) -> String? {
    guard let start = source.firstIndex(of: "\"") else { return nil }
    var index = source.index(after: start)
    var escaped = false
    while index < source.endIndex {
        let char = source[index]
        if char == "\"" && !escaped { return String(source[source.index(after: start)..<index]) }
        escaped = char == "\\" && !escaped
        if char != "\\" { escaped = false }
        index = source.index(after: index)
    }
    return nil
}
