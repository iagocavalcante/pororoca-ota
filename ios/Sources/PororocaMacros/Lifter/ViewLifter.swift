import Foundation
import SwiftSyntax

struct LiftOptions {
    var screen: String
    var colors: String
    var spaces: String
    var radii: String
    var strings: String
}

struct LiftedView {
    var root: String
    var state: [(name: String, type: String)]
    var actions: [String]
    var colorTokens: Set<String>
    var spaceTokens: Set<String>
    var radiusTokens: Set<String>
}

/// Syntax-backed SwiftUI subset lifter. SwiftSyntax locates declarations and
/// attributes; the small expression parser preserves source order verbatim.
struct ViewLifter {
    let declaration: StructDeclSyntax
    let options: LiftOptions

    func lift() throws -> LiftedView {
        let states = stateProperties()
        let markedActions = actionMethods()
        guard let content = computedProperty(named: "content") else {
            throw LiftFailure(diagnostic: .missingContent, node: Syntax(declaration.name))
        }
        let expressionSource = bodySource(of: content)
        let expr = ExprLifter(stateNames: Set(states.map(\.name)), stringsPath: options.strings)
        let parser = ViewSourceParser(
            options: options,
            expr: expr,
            actionNames: Set(markedActions),
            helpers: helperSources(excluding: "content"),
            parameterizedHelpers: Set(parameterizedHelperNames())
        )
        let root = try parser.lift(expressionSource)
        return .init(
            root: root,
            state: states,
            actions: markedActions.filter { parser.usedActions.contains($0) },
            colorTokens: parser.colorTokens,
            spaceTokens: parser.spaceTokens,
            radiusTokens: parser.radiusTokens
        )
    }

    private func stateProperties() -> [(name: String, type: String)] {
        declaration.memberBlock.members.compactMap { member in
            guard let variable = member.decl.as(VariableDeclSyntax.self), hasAttribute("OTAState", on: variable),
                  let binding = variable.bindings.first,
                  let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
            else { return nil }
            return (name, binding.typeAnnotation?.type.trimmedDescription ?? "String")
        }
    }

    private func actionMethods() -> [String] {
        declaration.memberBlock.members.compactMap { member in
            guard let function = member.decl.as(FunctionDeclSyntax.self), hasAttribute("OTAAction", on: function) else { return nil }
            return function.name.text
        }
    }

    private func computedProperty(named name: String) -> VariableDeclSyntax? {
        declaration.memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }.first {
            $0.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == name && $0.bindings.first?.accessorBlock != nil
        }
    }

    private func helperSources(excluding excluded: String) -> [String: String] {
        var result: [String: String] = [:]
        for member in declaration.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self), let binding = variable.bindings.first,
                  let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text, name != excluded,
                  binding.accessorBlock != nil else { continue }
            result[name] = bodySource(of: variable)
        }
        return result
    }

    private func parameterizedHelperNames() -> [String] {
        declaration.memberBlock.members.compactMap { member in
            guard let function = member.decl.as(FunctionDeclSyntax.self), !function.signature.parameterClause.parameters.isEmpty else { return nil }
            return function.name.text
        }
    }

    private func bodySource(of variable: VariableDeclSyntax) -> String {
        guard let accessors = variable.bindings.first?.accessorBlock?.accessors else { return "" }
        switch accessors {
        case let .getter(items): return items.trimmedDescription
        case let .accessors(list):
            return list.first(where: { $0.accessorSpecifier.text == "get" })?.body?.statements.trimmedDescription ?? ""
        }
    }

    private func hasAttribute(_ name: String, on declaration: some WithAttributesSyntax) -> Bool {
        declaration.attributes.contains { element in
            element.as(AttributeSyntax.self)?.attributeName.trimmedDescription == name
        }
    }
}

private final class ViewSourceParser {
    let options: LiftOptions
    let expr: ExprLifter
    let actionNames: Set<String>
    let helpers: [String: String]
    let parameterizedHelpers: Set<String>
    var helperStack: Set<String> = []
    var itemNames: Set<String> = []
    var usedActions: Set<String> = []
    var colorTokens: Set<String> = []
    var spaceTokens: Set<String> = []
    var radiusTokens: Set<String> = []

    init(options: LiftOptions, expr: ExprLifter, actionNames: Set<String>, helpers: [String: String], parameterizedHelpers: Set<String>) {
        self.options = options
        self.expr = expr
        self.actionNames = actionNames
        self.helpers = helpers
        self.parameterizedHelpers = parameterizedHelpers
    }

    func lift(_ source: String) throws -> String {
        var text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("return ") { text = String(text.dropFirst(7)) }
        if text.hasPrefix("switch ") || text.hasPrefix("guard ") || text.hasPrefix("if case ") || text.hasPrefix("if let ") {
            throw LiftFailure(diagnostic: .unsupportedControlFlow, node: Syntax(TokenSyntax.identifier("control flow")))
        }
        if text.hasPrefix("if ") { return try liftIf(text) }
        if let ternary = splitTernary(text) {
            return "PororocaDSL.If(\(try expr.condition(ternary.condition))) {\n\(indent(try lift(ternary.thenSource)))\n} else: {\n\(indent(try lift(ternary.elseSource)))\n}"
        }

        let chain = splitModifierChain(text)
        var result = try liftBase(chain.base)
        let modifiers = ModifierLifter(colors: options.colors, spaces: options.spaces, radii: options.radii, expr: expr)
        for call in chain.modifiers {
            collectTokens(in: call.arguments)
            result = try modifiers.apply(name: call.name, arguments: call.arguments, to: result)
        }
        return result
    }

    private func liftBase(_ source: String) throws -> String {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if let helper = helpers[text] {
            guard helperStack.insert(text).inserted else { throw LiftFailure(diagnostic: .unsupportedView, node: Syntax(TokenSyntax.identifier(text))) }
            defer { helperStack.remove(text) }
            return try lift(helper)
        }
        guard let name = callName(text) else {
            throw LiftFailure(diagnostic: .unsupportedView, node: Syntax(TokenSyntax.identifier(text)))
        }
        if parameterizedHelpers.contains(name) {
            throw LiftFailure(diagnostic: .parameterizedHelper, node: Syntax(TokenSyntax.identifier(name)))
        }
        guard Whitelist.views.contains(name) else {
            throw LiftFailure(diagnostic: .unsupportedView, node: Syntax(TokenSyntax.identifier(name)))
        }
        let args = callArguments(text)
        switch name {
        case "VStack", "HStack", "ZStack":
            let liftedArgs = try stackArguments(name: name, source: args)
            return "PororocaDSL.\(name)(\(liftedArgs)) {\n\(indent(try liftBuilder(trailingClosure(text))))\n}"
        case "ScrollView":
            return "PororocaDSL.ScrollView {\n\(indent(try liftBuilder(trailingClosure(text))))\n}"
        case "Spacer":
            if args.isEmpty { return "PororocaDSL.Spacer()" }
            let raw = splitArguments(args).last?.split(separator: ":", maxSplits: 1).last.map(String.init) ?? "0"
            return "PororocaDSL.Spacer(minLength: \(try dimension(raw)))"
        case "Text":
            let trimmed = args.trimmingCharacters(in: .whitespacesAndNewlines)
            if let dot = trimmed.firstIndex(of: "."), itemNames.contains(String(trimmed[..<dot])) {
                return "PororocaDSL.Text(Expr.item(\(quoted(String(trimmed[trimmed.index(after: dot)...])))))"
            }
            return "PororocaDSL.Text(\(try expr.textArgument(args)))"
        case "Image":
            guard args.contains("systemName:"), let value = firstStringLiteral(in: args) else {
                throw LiftFailure(diagnostic: .unsupportedView, node: Syntax(TokenSyntax.identifier("Image")))
            }
            return "PororocaDSL.Icon(\(quoted(value)))"
        case "Button": return try liftButton(text)
        case "ForEach": return try liftForEach(text, arguments: args)
        case "ProgressView": return "PororocaDSL.Progress()"
        case "RoundedRectangle":
            let first = splitArguments(args).first?.split(separator: ":", maxSplits: 1).last.map(String.init) ?? "0"
            return "PororocaDSL.RoundedRectangle(cornerRadius: \(try radius(first)))"
        default: return "PororocaDSL.\(name)()"
        }
    }

    private func liftBuilder(_ source: String) throws -> String {
        let statements = splitStatements(source)
        return try statements.map(lift).joined(separator: "\n")
    }

    private func liftIf(_ source: String) throws -> String {
        guard let open = source.firstIndex(of: "{"),
              let close = matchingDelimiter(in: source, from: open, open: "{", close: "}") else {
            throw LiftFailure(diagnostic: .unsupportedControlFlow, node: Syntax(TokenSyntax.identifier("if")))
        }
        let conditionSource = String(source[source.index(source.startIndex, offsetBy: 3)..<open])
        let thenSource = String(source[source.index(after: open)..<close])
        let tail = String(source[source.index(after: close)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let condition = try expr.condition(conditionSource)
        if tail.hasPrefix("else"), let elseOpen = tail.firstIndex(of: "{"),
           let elseClose = matchingDelimiter(in: tail, from: elseOpen, open: "{", close: "}") {
            let elseSource = String(tail[tail.index(after: elseOpen)..<elseClose])
            return "PororocaDSL.If(\(condition)) {\n\(indent(try liftBuilder(thenSource)))\n} else: {\n\(indent(try liftBuilder(elseSource)))\n}"
        }
        return "PororocaDSL.If(\(condition)) {\n\(indent(try liftBuilder(thenSource)))\n}"
    }

    private func liftButton(_ source: String) throws -> String {
        let closures = allTopLevelClosures(source)
        guard closures.count >= 2 else { throw LiftFailure(diagnostic: .unsupportedView, node: Syntax(TokenSyntax.identifier("Button"))) }
        let actionBody = closures[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let action = actionBody.replacingOccurrences(of: "self.", with: "").replacingOccurrences(of: "()", with: "")
        guard actionNames.contains(action) else {
            throw LiftFailure(diagnostic: .actionNotOTAAction, node: Syntax(TokenSyntax.identifier(action)))
        }
        usedActions.insert(action)
        return "PororocaDSL.Button(__PororocaAction.\(action)) {\n\(indent(try liftBuilder(closures[1])))\n}"
    }

    private func liftForEach(_ source: String, arguments: String) throws -> String {
        let parts = splitArguments(arguments)
        guard let collection = parts.first else { throw LiftFailure(diagnostic: .unsupportedView, node: Syntax(TokenSyntax.identifier("ForEach"))) }
        let stateName = collection.replacingOccurrences(of: "self.", with: "").trimmingCharacters(in: .whitespaces)
        guard expr.stateNames.contains(stateName) else { throw LiftFailure(diagnostic: .notOTAState, node: Syntax(TokenSyntax.identifier(stateName))) }
        let keyPart = parts.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("id:") }) ?? "id: \\.id"
        let key = keyPart.split(separator: ":", maxSplits: 1).last.map(String.init)?.trimmingCharacters(in: CharacterSet(charactersIn: " \\.")) ?? "id"
        let closure = trailingClosure(source)
        let split = closure.split(separator: "in", maxSplits: 1).map(String.init)
        guard split.count == 2 else { throw LiftFailure(diagnostic: .unsupportedView, node: Syntax(TokenSyntax.identifier("ForEach"))) }
        let itemName = split[0].trimmingCharacters(in: .whitespacesAndNewlines)
        itemNames.insert(itemName)
        defer { itemNames.remove(itemName) }
        return "PororocaDSL.ForEach(state.\(stateName), key: \(quoted(key))) { _ in\n\(indent(try liftBuilder(split[1])))\n}"
    }

    private func stackArguments(name: String, source: String) throws -> String {
        guard !source.isEmpty else { return "" }
        var spacing: String?
        var alignment: String?
        for part in splitArguments(source) {
            let bits = part.split(separator: ":", maxSplits: 1).map(String.init)
            guard bits.count == 2 else { continue }
            let label = bits[0].trimmingCharacters(in: .whitespaces)
            let raw = bits[1].trimmingCharacters(in: .whitespaces)
            if label == "spacing" { spacing = "spacing: \(try dimension(raw))" }
            else { alignment = "\(label): \(raw)" }
        }
        return [spacing, alignment].compactMap { $0 }.joined(separator: ", ")
    }

    private func dimension(_ source: String) throws -> String {
        collectTokens(in: source)
        return try ModifierLifter(colors: options.colors, spaces: options.spaces, radii: options.radii, expr: expr).dimension(source)
    }

    private func radius(_ source: String) throws -> String {
        collectTokens(in: source)
        return try ModifierLifter(colors: options.colors, spaces: options.spaces, radii: options.radii, expr: expr).radius(source)
    }

    private func collectTokens(in source: String) {
        collect(namespace: options.colors, source: source, into: &colorTokens)
        collect(namespace: options.spaces, source: source, into: &spaceTokens)
        collect(namespace: options.radii, source: source, into: &radiusTokens)
    }

    private func collect(namespace: String, source: String, into set: inout Set<String>) {
        let prefix = namespace + "."
        var rest = source
        while let range = rest.range(of: prefix) {
            let start = range.upperBound
            let suffix = rest[start...]
            let name = suffix.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
            if !name.isEmpty { set.insert(String(name)) }
            rest = String(suffix.dropFirst(name.count))
        }
    }
}

private struct ModifierCall { var name: String; var arguments: String }

private func splitModifierChain(_ source: String) -> (base: String, modifiers: [ModifierCall]) {
    let chars = Array(source)
    var depths = (round: 0, square: 0, curly: 0)
    var inString = false
    var escaped = false
    var starts: [Int] = []
    for i in chars.indices {
        let char = chars[i]
        if inString {
            if char == "\"" && !escaped { inString = false }
            escaped = char == "\\" && !escaped
            if char != "\\" { escaped = false }
            continue
        }
        if char == "\"" { inString = true; continue }
        switch char {
        case "(": depths.round += 1
        case ")": depths.round -= 1
        case "[": depths.square += 1
        case "]": depths.square -= 1
        case "{": depths.curly += 1
        case "}": depths.curly -= 1
        case "." where depths == (0, 0, 0):
            if i + 1 < chars.count, chars[i + 1].isLetter { starts.append(i) }
        default: break
        }
    }
    guard let first = starts.first else { return (source, []) }
    let base = String(chars[..<first])
    var calls: [ModifierCall] = []
    for (offset, start) in starts.enumerated() {
        let end = offset + 1 < starts.count ? starts[offset + 1] : chars.count
        let segment = String(chars[(start + 1)..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        let name = segment.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
        calls.append(.init(name: String(name), arguments: callArguments(segment)))
    }
    return (base, calls)
}

private func callName(_ source: String) -> String? {
    let name = source.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
    return name.isEmpty ? nil : String(name)
}

private func trailingClosure(_ source: String) -> String {
    guard let open = topLevelOpeningBrace(in: source), let close = matchingDelimiter(in: source, from: open, open: "{", close: "}") else { return "" }
    return String(source[source.index(after: open)..<close])
}

private func allTopLevelClosures(_ source: String) -> [String] {
    var result: [String] = []
    var cursor = source.startIndex
    while cursor < source.endIndex {
        guard let open = source[cursor...].firstIndex(of: "{"), let close = matchingDelimiter(in: source, from: open, open: "{", close: "}") else { break }
        result.append(String(source[source.index(after: open)..<close]))
        cursor = source.index(after: close)
    }
    return result
}

private func topLevelOpeningBrace(in source: String) -> String.Index? {
    var round = 0
    for index in source.indices {
        if source[index] == "(" { round += 1 }
        else if source[index] == ")" { round -= 1 }
        else if source[index] == "{" && round == 0 { return index }
    }
    return nil
}

func matchingDelimiter(in source: String, from start: String.Index, open: Character, close: Character) -> String.Index? {
    var depth = 0
    var inString = false
    var escaped = false
    var index = start
    while index < source.endIndex {
        let char = source[index]
        if inString {
            if char == "\"" && !escaped { inString = false }
            escaped = char == "\\" && !escaped
            if char != "\\" { escaped = false }
        } else if char == "\"" { inString = true }
        else if char == open { depth += 1 }
        else if char == close { depth -= 1; if depth == 0 { return index } }
        index = source.index(after: index)
    }
    return nil
}

func splitTopLevel(_ source: String, separator: Character) -> [String] {
    var result: [String] = []
    var start = source.startIndex
    var round = 0, square = 0, curly = 0
    var inString = false, escaped = false
    for index in source.indices {
        let char = source[index]
        if inString {
            if char == "\"" && !escaped { inString = false }
            escaped = char == "\\" && !escaped
            if char != "\\" { escaped = false }
            continue
        }
        if char == "\"" { inString = true; continue }
        switch char { case "(": round += 1; case ")": round -= 1; case "[": square += 1; case "]": square -= 1; case "{": curly += 1; case "}": curly -= 1; default: break }
        if char == separator && round == 0 && square == 0 && curly == 0 {
            result.append(String(source[start..<index]).trimmingCharacters(in: .whitespacesAndNewlines))
            start = source.index(after: index)
        }
    }
    let tail = String(source[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
    if !tail.isEmpty { result.append(tail) }
    return result
}

private func splitStatements(_ source: String) -> [String] {
    var result: [String] = []
    var start = source.startIndex
    var round = 0, square = 0, curly = 0
    var inString = false, escaped = false
    var index = source.startIndex
    while index < source.endIndex {
        let char = source[index]
        if inString {
            if char == "\"" && !escaped { inString = false }
            escaped = char == "\\" && !escaped
            if char != "\\" { escaped = false }
        } else if char == "\"" { inString = true }
        else {
            switch char { case "(": round += 1; case ")": round -= 1; case "[": square += 1; case "]": square -= 1; case "{": curly += 1; case "}": curly -= 1; default: break }
            if (char == "\n" || char == ";") && round == 0 && square == 0 && curly == 0 {
                let piece = String(source[start..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
                let next = source[source.index(after: index)...].drop(while: { $0.isWhitespace })
                if !piece.isEmpty && !next.hasPrefix(".") && !next.hasPrefix("else") {
                    result.append(piece)
                    start = source.index(after: index)
                }
            }
        }
        index = source.index(after: index)
    }
    let tail = String(source[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
    if !tail.isEmpty { result.append(tail) }
    return result
}

private func indent(_ source: String) -> String { source.split(separator: "\n", omittingEmptySubsequences: false).map { "    " + $0 }.joined(separator: "\n") }

private func splitTernary(_ source: String) -> (condition: String, thenSource: String, elseSource: String)? {
    var round = 0, square = 0, curly = 0
    var question: String.Index?
    for index in source.indices {
        switch source[index] { case "(": round += 1; case ")": round -= 1; case "[": square += 1; case "]": square -= 1; case "{": curly += 1; case "}": curly -= 1; default: break }
        if source[index] == "?", round == 0, square == 0, curly == 0 { question = index }
        if source[index] == ":", let question, round == 0, square == 0, curly == 0 {
            return (
                String(source[..<question]),
                String(source[source.index(after: question)..<index]),
                String(source[source.index(after: index)...])
            )
        }
    }
    return nil
}
