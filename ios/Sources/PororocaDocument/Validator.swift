import Foundation
import PororocaExpr

/// Capabilities compiled into a screen host.
public struct HostCapabilities: Sendable, Equatable, Codable {
    public var runtime: String
    public var state: [String: StateType]
    public var actions: [String]
    public var slots: [String]
    public var tokens: TokenRequirements
    public var strings: [String]
    public var assets: [String]

    public init(runtime: String, state: [String: StateType] = [:], actions: [String] = [], slots: [String] = [], tokens: TokenRequirements = .init(), strings: [String] = [], assets: [String] = []) {
        self.runtime = runtime; self.state = state; self.actions = actions; self.slots = slots; self.tokens = tokens; self.strings = strings; self.assets = assets
    }

    public init(_ requires: Requires) {
        self.init(runtime: requires.runtime, state: requires.state, actions: requires.actions, slots: requires.slots, tokens: requires.tokens, strings: requires.strings, assets: requires.assets)
    }

    public init(from decoder: Decoder) throws {
        self.init(try Requires(from: decoder))
    }

    public func encode(to encoder: Encoder) throws {
        try Requires(runtime: runtime, state: state, actions: actions, slots: slots, tokens: tokens, strings: strings, assets: assets).encode(to: encoder)
    }
}

/// Static expression types used by document validation.
public enum ExpressionType: String, Sendable, Equatable {
    case bool, string, number, array, object, null, any
}

/// Strict schema, semantic, resource, and host-capability validation.
public enum Validator {
    /// Decodes and validates raw document bytes, mapping every codec failure to a validation error.
    public static func validate(_ data: Data, against host: HostCapabilities? = nil) -> [ValidationError] {
        do { return validate(try DocumentCodec.decode(data), against: host) }
        catch let error as StrictDecodingError { return [.init(code: .unknownKey, path: error.path, detail: error.key)] }
        catch let error as DocumentCodecError { return [.init(code: map(error.code), path: error.path, detail: error.detail)] }
        catch let error as ExprCodecError { return [.init(code: error.code == .unknownOperator ? .unknownOperator : .malformed, path: error.path, detail: error.detail)] }
        catch let error as DecodingError { return [.init(code: .malformed, path: decodingPath(error), detail: String(describing: error))] }
        catch { return [.init(code: .malformed, path: .init([]), detail: String(describing: error))] }
    }

    /// Validates a decoded document and returns all discovered errors.
    public static func validate(_ document: Document, against host: HostCapabilities? = nil) -> [ValidationError] {
        var context = Context(document: document)
        if document.format != 1 { context.add(.unsupportedFormat, ["format"], "expected 1, got \(document.format)") }
        context.visit(document.root, path: ["root"], depth: 1, insideForEach: false)
        if context.nodeCount > 5_000 { context.add(.nodeLimit, ["root"], "maximum 5000 nodes, got \(context.nodeCount)") }
        if let host { context.checkCapabilities(host) }
        return context.errors
    }

    private static func map(_ code: DocumentCodecError.Code) -> ValidationError.Code {
        switch code { case .unknownKind: .unknownKind; case .childCount: .childCount; case .unexpectedChildren: .unexpectedChildren; case .invalidValue: .invalidValue }
    }

    private static func decodingPath(_ error: DecodingError) -> JSONPath {
        switch error {
        case let .typeMismatch(_, context), let .valueNotFound(_, context), let .dataCorrupted(context): JSONPath(codingPath: context.codingPath)
        case let .keyNotFound(key, context): JSONPath(codingPath: context.codingPath).appending(key.stringValue)
        @unknown default: JSONPath([])
        }
    }
}

private struct Context {
    let document: Document
    var errors: [ValidationError] = []
    var nodeCount = 0

    mutating func add(_ code: ValidationError.Code, _ path: [String], _ detail: String) {
        errors.append(.init(code: code, path: .init(path), detail: detail))
    }

    mutating func visit(_ node: Node, path: [String], depth: Int, insideForEach: Bool) {
        nodeCount += 1
        guard depth <= 64 else { add(.depthLimit, path, "maximum node depth is 64"); return }
        if let mod = node.mod { visit(mod, path: path + ["mod"], insideForEach: insideForEach) }

        switch node.kind {
        case let .vstack(spacing, _, children):
            visit(spacing, path: path + ["p", "spacing"]); visitChildren(children, path: path, depth: depth, insideForEach: insideForEach)
        case let .hstack(spacing, _, children):
            visit(spacing, path: path + ["p", "spacing"]); visitChildren(children, path: path, depth: depth, insideForEach: insideForEach)
        case let .zstack(_, children):
            visitChildren(children, path: path, depth: depth, insideForEach: insideForEach)
        case let .box(child):
            visit(child, path: path + ["c", "0"], depth: depth + 1, insideForEach: insideForEach)
        case let .spacer(minLength):
            visit(minLength, path: path + ["p", "minLength"])
        case let .scroll(_, child):
            visit(child, path: path + ["c", "0"], depth: depth + 1, insideForEach: insideForEach)
        case let .lazycolumn(spacing, children):
            visit(spacing, path: path + ["p", "spacing"]); visitChildren(children, path: path, depth: depth, insideForEach: insideForEach)
        case let .text(value):
            _ = infer(value, path: path + ["p", "value"], insideForEach: insideForEach)
        case .icon:
            break
        case let .image(source, _):
            if case let .asset(name) = source, !document.requires.assets.contains(name) { add(.undeclaredAsset, path + ["p", "source", "$asset"], name) }
        case let .shape(_, cornerRadius, fill):
            visit(cornerRadius, path: path + ["p", "cornerRadius"]); visit(fill, path: path + ["p", "fill"])
        case .divider:
            break
        case let .progress(tint):
            visit(tint, path: path + ["p", "tint"])
        case let .button(action, _, label):
            visit(action, path: path + ["p", "action"], insideForEach: insideForEach)
            visit(label, path: path + ["c", "0"], depth: depth + 1, insideForEach: insideForEach)
        case let .if(condition, thenNode, elseNode):
            let type = infer(condition, path: path + ["p", "cond"], insideForEach: insideForEach)
            require(type, is: .bool, path: path + ["p", "cond"], detail: "if condition must be bool")
            visit(thenNode, path: path + ["p", "then"], depth: depth + 1, insideForEach: insideForEach)
            if let elseNode { visit(elseNode, path: path + ["p", "else"], depth: depth + 1, insideForEach: insideForEach) }
        case let .foreach(items, _, template):
            let type = infer(items, path: path + ["p", "items"], insideForEach: insideForEach)
            require(type, is: .array, path: path + ["p", "items"], detail: "foreach items must be array")
            visit(template, path: path + ["p", "template"], depth: depth + 1, insideForEach: true)
        case let .slot(name, props):
            if !document.requires.slots.contains(name) { add(.undeclaredSlot, path + ["p", "name"], name) }
            for key in props.keys.sorted() {
                if case let .string(value) = props[key] { _ = infer(value, path: path + ["p", "props", key], insideForEach: insideForEach) }
            }
        }
    }

    mutating func visitChildren(_ children: [Node], path: [String], depth: Int, insideForEach: Bool) {
        for (index, child) in children.enumerated() { visit(child, path: path + ["c", String(index)], depth: depth + 1, insideForEach: insideForEach) }
    }

    mutating func visit(_ mod: ModifierProps, path: [String], insideForEach: Bool) {
        visit(mod.font, path: path + ["font"]); visit(mod.foreground, path: path + ["foreground"])
        for (index, padding) in mod.padding.enumerated() {
            let suffix = mod.padding.count == 1 ? ["padding"] : ["padding", String(index)]
            visit(padding.value, path: path + suffix + ["value"])
            for previous in mod.padding.prefix(index) where previous.edges.overlaps(padding.edges) { add(.overlappingPadding, path + suffix + ["edges"], "\(previous.edges.rawValue) overlaps \(padding.edges.rawValue)"); break }
        }
        visit(mod.background, path: path + ["background"])
        if let frame = mod.frame {
            let dimensions: [(String, FrameDimension?)] = [("width", frame.width), ("height", frame.height), ("minWidth", frame.minWidth), ("maxWidth", frame.maxWidth), ("minHeight", frame.minHeight), ("maxHeight", frame.maxHeight)]
            for (name, dimension) in dimensions { if case let .points(value)? = dimension, value < 0 { add(.negativeSize, path + ["frame", name], String(value)) } }
        }
        visit(mod.cornerRadius?.radius, path: path + ["cornerRadius", "radius"])
        if let border = mod.border { visit(border.color, path: path + ["border", "color"]); if border.width < 0 { add(.negativeSize, path + ["border", "width"], String(border.width)) } }
        if let shadow = mod.shadow { visit(shadow.color, path: path + ["shadow", "color"]); if shadow.radius < 0 { add(.negativeSize, path + ["shadow", "radius"], String(shadow.radius)) } }
        if let opacity = mod.opacity, !(0...1).contains(opacity) { add(.invalidOpacity, path + ["opacity"], String(opacity)) }
        if let disabled = mod.disabled { let type = infer(disabled, path: path + ["disabled"], insideForEach: insideForEach); require(type, is: .bool, path: path + ["disabled"], detail: "disabled must be bool") }
        if let hidden = mod.hidden { let type = infer(hidden, path: path + ["hidden"], insideForEach: insideForEach); require(type, is: .bool, path: path + ["hidden"], detail: "hidden must be bool") }
        if let label = mod.accessibilityLabel { _ = infer(label, path: path + ["accessibilityLabel"], insideForEach: insideForEach) }
    }

    mutating func visit(_ action: Action, path: [String], insideForEach: Bool) {
        if !Action.builtinNames.contains(action.name), !document.requires.actions.contains(action.name) { add(.undeclaredAction, path + ["name"], action.name) }
        for key in action.args.keys.sorted() { if let expression = action.args[key] { _ = infer(expression, path: path + ["args", key], insideForEach: insideForEach) } }
    }

    mutating func infer(_ string: Str, path: [String], insideForEach: Bool) -> ExpressionType {
        switch string {
        case .literal: return .string
        case let .localized(key):
            if !document.requires.strings.contains(key) { add(.undeclaredString, path + ["$t"], key) }; return .string
        case let .expr(expression): return infer(expression, path: path + ["expr"], insideForEach: insideForEach)
        }
    }

    mutating func infer(_ expression: Expr, path: [String], insideForEach: Bool, depth: Int = 1) -> ExpressionType {
        guard depth <= 64 else { add(.depthLimit, path, "maximum expression depth is 64"); return .any }
        let childDepth = depth + 1
        switch expression {
        case let .literal(value): return type(of: value)
        case let .state(key):
            guard let type = document.requires.state[key] else { add(.undeclaredState, path + ["state"], key); return .any }; return expressionType(type)
        case let .local(key):
            guard let value = document.local[key] else { add(.undeclaredLocal, path + ["local"], key); return .any }; return type(of: value)
        case .item:
            if !insideForEach { add(.itemOutsideForEach, path + ["item"], "item may only be used inside foreach") }; return .any
        case .index:
            if !insideForEach { add(.itemOutsideForEach, path + ["index"], "index may only be used inside foreach") }; return .number
        case let .localized(key):
            if !document.requires.strings.contains(key) { add(.undeclaredString, path + ["$t"], key) }; return .string
        case let .eq(a, b), let .ne(a, b): _ = infer(a, path: path + ["0"], insideForEach: insideForEach, depth: childDepth); _ = infer(b, path: path + ["1"], insideForEach: insideForEach, depth: childDepth); return .bool
        case let .lt(a, b), let .le(a, b), let .gt(a, b), let .ge(a, b):
            let left = infer(a, path: path + ["0"], insideForEach: insideForEach, depth: childDepth); let right = infer(b, path: path + ["1"], insideForEach: insideForEach, depth: childDepth)
            require(left, is: .number, path: path + ["0"], detail: "ordering operand must be number"); require(right, is: .number, path: path + ["1"], detail: "ordering operand must be number"); return .bool
        case let .and(values), let .or(values):
            for (index, value) in values.enumerated() { let type = infer(value, path: path + [String(index)], insideForEach: insideForEach, depth: childDepth); require(type, is: .bool, path: path + [String(index)], detail: "boolean operand must be bool") }; return .bool
        case let .not(value): let type = infer(value, path: path + ["0"], insideForEach: insideForEach, depth: childDepth); require(type, is: .bool, path: path + ["0"], detail: "not operand must be bool"); return .bool
        case let .coalesce(values):
            let types = values.enumerated().map { infer($0.element, path: path + [String($0.offset)], insideForEach: insideForEach, depth: childDepth) }.filter { $0 != .null }
            return types.dropFirst().allSatisfy { $0 == types.first } ? (types.first ?? .null) : .any
        case let .concat(values): for (index, value) in values.enumerated() { _ = infer(value, path: path + [String(index)], insideForEach: insideForEach, depth: childDepth) }; return .string
        case let .fmt(format):
            let value: Expr
            switch format { case let .number(v, _), let .currency(v, _), let .date(v, _), let .plural(v, _): value = v }
            let type = infer(value, path: path + ["value"], insideForEach: insideForEach, depth: childDepth); require(type, is: .number, path: path + ["value"], detail: "format value must be number"); return .string
        case let .case(on, cases, defaultValue):
            _ = infer(on, path: path + ["on"], insideForEach: insideForEach, depth: childDepth)
            var types = cases.keys.sorted().compactMap { key in cases[key].map { infer($0, path: path + ["cases", key], insideForEach: insideForEach, depth: childDepth) } }
            if let defaultValue { types.append(infer(defaultValue, path: path + ["default"], insideForEach: insideForEach, depth: childDepth)) }
            return types.dropFirst().allSatisfy { $0 == types.first } ? (types.first ?? .any) : .any
        case let .count(value): _ = infer(value, path: path + ["0"], insideForEach: insideForEach, depth: childDepth); return .number
        case let .empty(value): _ = infer(value, path: path + ["0"], insideForEach: insideForEach, depth: childDepth); return .bool
        }
    }

    mutating func require(_ actual: ExpressionType, is expected: ExpressionType, path: [String], detail: String) {
        if actual != expected, actual != .any { add(.typeMismatch, path, "\(detail), got \(actual.rawValue)") }
    }

    func type(of value: Value) -> ExpressionType { switch value { case .null: .null; case .bool: .bool; case .number: .number; case .string: .string; case .array: .array; case .object: .object } }
    func expressionType(_ type: StateType) -> ExpressionType { switch type { case .string, .optionalString: .string; case .bool, .optionalBool: .bool; case .number, .optionalNumber: .number; case .array: .array } }

    mutating func visit(_ value: Dim?, path: [String]) { if case let .token(name)? = value, !document.requires.tokens.space.contains(name) { add(.undeclaredToken, path + ["$space"], "space:\(name)") }; if case let .points(points)? = value, points < 0 { add(.negativeSize, path, String(points)) } }
    mutating func visit(_ value: Radius?, path: [String]) { if case let .token(name)? = value, !document.requires.tokens.radius.contains(name) { add(.undeclaredToken, path + ["$radius"], "radius:\(name)") }; if case let .points(points)? = value, points < 0 { add(.negativeSize, path, String(points)) } }
    mutating func visit(_ value: FontValue?, path: [String]) { guard let value else { return }; switch value { case let .token(name): if !document.requires.tokens.font.contains(name) { add(.undeclaredToken, path + ["$font"], "font:\(name)") }; case let .system(font): if font.size < 0 { add(.negativeSize, path + ["system", "size"], String(font.size)) } } }
    mutating func visit(_ value: ColorValue?, path: [String]) { guard case let .token(name, opacity)? = value else { return }; if !document.requires.tokens.color.contains(name) { add(.undeclaredToken, path + ["$color"], "color:\(name)") }; if let opacity, !(0...1).contains(opacity) { add(.invalidOpacity, path + ["opacity"], String(opacity)) } }
    mutating func visit(_ value: Paint?, path: [String]) { guard let value else { return }; switch value { case let .color(color): visit(color, path: path); case let .gradient(.linear(gradient)): for (index, color) in gradient.colors.enumerated() { visit(color, path: path + ["linear", "colors", String(index)]) } } }

    mutating func checkCapabilities(_ host: HostCapabilities) {
        var missing: [String] = []
        if !runtime(host.runtime, satisfies: document.requires.runtime) { missing.append("runtime:\(document.requires.runtime)") }
        for key in document.requires.state.keys.sorted() where host.state[key] != document.requires.state[key] { missing.append("state:\(key)") }
        missing += missingNames(document.requires.actions, in: host.actions, prefix: "action")
        missing += missingNames(document.requires.slots, in: host.slots, prefix: "slot")
        missing += missingNames(document.requires.tokens.color, in: host.tokens.color, prefix: "color")
        missing += missingNames(document.requires.tokens.space, in: host.tokens.space, prefix: "space")
        missing += missingNames(document.requires.tokens.radius, in: host.tokens.radius, prefix: "radius")
        missing += missingNames(document.requires.tokens.font, in: host.tokens.font, prefix: "font")
        missing += missingNames(document.requires.strings, in: host.strings, prefix: "string")
        missing += missingNames(document.requires.assets, in: host.assets, prefix: "asset")
        if !missing.isEmpty { add(.capabilityMissing, ["requires"], missing.sorted().joined(separator: ", ")) }
    }

    func missingNames(_ required: [String], in available: [String], prefix: String) -> [String] { let values = Set(available); return required.filter { !values.contains($0) }.map { "\(prefix):\($0)" } }
    func runtime(_ version: String, satisfies requirement: String) -> Bool {
        if version == requirement { return true }
        guard requirement.hasPrefix(">=") else { return version == requirement }
        let actual = versionTuple(version)
        let required = versionTuple(String(requirement.dropFirst(2)))
        for (lhs, rhs) in zip(actual, required) {
            if lhs != rhs { return lhs > rhs }
        }
        return true
    }
    func versionTuple(_ value: String) -> [Int] { value.split(separator: ".").prefix(3).map { Int($0) ?? 0 } + Array(repeating: 0, count: max(0, 3 - value.split(separator: ".").count)) }
}
