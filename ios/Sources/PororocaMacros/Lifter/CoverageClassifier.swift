import Foundation
import SwiftParser
import SwiftSyntax

public enum CoverageBucket: String, Codable, Sendable, CaseIterable {
    case clean, small, no
}

public enum CoverageReasonCode: String, Codable, Sendable {
    case notOTAState
    case unsupportedView
    case unsupportedModifier
    case unsupportedControlFlow
    case parameterizedHelper
    case actionNotOTAAction
}

public struct CoverageReason: Codable, Sendable, Hashable {
    public var code: CoverageReasonCode
    public var detail: String

    public init(code: CoverageReasonCode, detail: String) {
        self.code = code
        self.detail = detail
    }
}

public struct CoverageEntry: Codable, Sendable {
    public var file: String
    public var view: String
    public var bucket: CoverageBucket
    public var reasons: [CoverageReason]

    public init(file: String, view: String, bucket: CoverageBucket, reasons: [CoverageReason]) {
        self.file = file
        self.view = view
        self.bucket = bucket
        self.reasons = reasons
    }
}

public struct CoverageSummary: Codable, Sendable {
    public var root: String
    public var entries: [CoverageEntry]

    public init(root: String, entries: [CoverageEntry]) {
        self.root = root
        self.entries = entries
    }

    public var total: Int { entries.count }
    public func count(_ bucket: CoverageBucket) -> Int { entries.count { $0.bucket == bucket } }
    public func percentage(_ bucket: CoverageBucket) -> Double {
        guard total > 0 else { return 0 }
        return Double(count(bucket)) * 100 / Double(total)
    }

    public var topNoReasons: [(reason: CoverageReason, count: Int)] {
        var counts: [CoverageReason: Int] = [:]
        for entry in entries where entry.bucket == .no {
            for reason in Set(entry.reasons) { counts[reason, default: 0] += 1 }
        }
        return counts.map { ($0.key, $0.value) }.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            if $0.0.code.rawValue != $1.0.code.rawValue { return $0.0.code.rawValue < $1.0.code.rawValue }
            return $0.0.detail < $1.0.detail
        }
    }
}

public enum CoverageClassifier {
    private static let supportedViews: Set<String> = [
        "VStack", "HStack", "ZStack", "ScrollView", "Spacer", "Text", "Image", "Button",
        "ProgressView", "Rectangle", "RoundedRectangle", "Capsule", "Circle", "Divider", "ForEach",
    ]
    private static let supportedModifiers: Set<String> = [
        "padding", "background", "frame", "foregroundStyle", "font", "clipShape", "opacity",
        "lineLimit", "minimumScaleFactor", "multilineTextAlignment", "fixedSize", "disabled",
        "ignoresSafeArea", "tint", "buttonStyle", "progressViewStyle", "fill", "defaultScrollAnchor",
    ]

    public static func classify(directory: URL) throws -> CoverageSummary {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { throw CocoaError(.fileReadNoSuchFile) }

        let files = enumerator.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.path < $1.path }
        var entries: [CoverageEntry] = []
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            let syntax = Parser.parse(source: source)
            let collector = ViewCollector(viewMode: .sourceAccurate)
            collector.walk(syntax)
            let relative = file.path.replacingOccurrences(of: directory.path + "/", with: "")
            entries += collector.views.compactMap { classify($0, file: relative) }
        }
        entries.sort { ($0.file, $0.view) < ($1.file, $1.view) }
        return CoverageSummary(root: directory.path, entries: entries)
    }

    public static func classify(sources: [String: String], root: String = "fixtures") -> CoverageSummary {
        var entries: [CoverageEntry] = []
        for (file, source) in sources.sorted(by: { $0.key < $1.key }) {
            let syntax = Parser.parse(source: source)
            let collector = ViewCollector(viewMode: .sourceAccurate)
            collector.walk(syntax)
            entries += collector.views.compactMap { classify($0, file: file) }
        }
        entries.sort { ($0.file, $0.view) < ($1.file, $1.view) }
        return CoverageSummary(root: root, entries: entries)
    }

    private static func classify(_ structure: StructDeclSyntax, file: String) -> CoverageEntry? {
        guard structure.inheritanceClause?.inheritedTypes.contains(where: {
            let name = $0.type.trimmedDescription
            return name == "View" || name.hasSuffix(".View")
        }) == true else { return nil }

        let variables = structure.memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }
        guard let body = variables.first(where: { variableName($0) == "content" })
            ?? variables.first(where: { variableName($0) == "body" }) else { return nil }

        let storedNames = Set(variables.compactMap { variable -> String? in
            guard variable.bindings.first?.accessorBlock == nil else { return nil }
            return variableName(variable)
        })
        let helperNames = Set(variables.compactMap { variable -> String? in
            guard variable.bindings.first?.accessorBlock != nil else { return nil }
            let name = variableName(variable)
            return name == "body" || name == "content" ? nil : name
        })
        let functions = structure.memberBlock.members.compactMap { $0.decl.as(FunctionDeclSyntax.self) }
        let functionNames = Set(functions.map { $0.name.text })
        let parameterized = Set(functions.filter { !$0.signature.parameterClause.parameters.isEmpty }.map { $0.name.text })

        let scanner = BodyScanner(
            storedNames: storedNames,
            helperNames: helperNames,
            functionNames: functionNames,
            parameterizedFunctions: parameterized,
            supportedViews: supportedViews,
            supportedModifiers: supportedModifiers,
            viewMode: .sourceAccurate
        )
        if let accessor = body.bindings.first?.accessorBlock { scanner.walk(accessor) }
        let bodyText = body.trimmedDescription
        if bodyText.contains("switch ") { scanner.add(.unsupportedControlFlow, "switch") }
        if bodyText.contains("if let ") { scanner.add(.unsupportedControlFlow, "if let") }
        if bodyText.contains("if case ") { scanner.add(.unsupportedControlFlow, "if case") }
        if bodyText.contains("guard ") { scanner.add(.unsupportedControlFlow, "guard") }

        let reasons = scanner.reasons.sorted {
            if $0.code.rawValue != $1.code.rawValue { return $0.code.rawValue < $1.code.rawValue }
            return $0.detail < $1.detail
        }
        let hardCodes: Set<CoverageReasonCode> = [.unsupportedView, .unsupportedModifier, .unsupportedControlFlow]
        let bucket: CoverageBucket = reasons.isEmpty ? .clean : reasons.contains(where: { hardCodes.contains($0.code) }) ? .no : .small
        return CoverageEntry(file: file, view: structure.name.text, bucket: bucket, reasons: reasons)
    }

    private static func variableName(_ variable: VariableDeclSyntax) -> String? {
        variable.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
    }
}

private final class ViewCollector: SyntaxVisitor {
    var views: [StructDeclSyntax] = []
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        views.append(node)
        return .visitChildren
    }
}

private final class BodyScanner: SyntaxVisitor {
    let storedNames: Set<String>
    let helperNames: Set<String>
    let functionNames: Set<String>
    let parameterizedFunctions: Set<String>
    let supportedViews: Set<String>
    let supportedModifiers: Set<String>
    var reasons: Set<CoverageReason> = []

    init(
        storedNames: Set<String>,
        helperNames: Set<String>,
        functionNames: Set<String>,
        parameterizedFunctions: Set<String>,
        supportedViews: Set<String>,
        supportedModifiers: Set<String>,
        viewMode: SyntaxTreeViewMode
    ) {
        self.storedNames = storedNames
        self.helperNames = helperNames
        self.functionNames = functionNames
        self.parameterizedFunctions = parameterizedFunctions
        self.supportedViews = supportedViews
        self.supportedModifiers = supportedModifiers
        super.init(viewMode: viewMode)
    }

    func add(_ code: CoverageReasonCode, _ detail: String) {
        reasons.insert(.init(code: code, detail: detail))
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        let called = node.calledExpression
        let name: String?
        let memberCall: MemberAccessExprSyntax?
        if let reference = called.as(DeclReferenceExprSyntax.self) {
            name = reference.baseName.text
            memberCall = nil
        } else if let member = called.as(MemberAccessExprSyntax.self) {
            name = member.declName.baseName.text
            memberCall = member
        } else {
            name = nil
            memberCall = nil
        }
        guard let name else { return .visitChildren }

        if parameterizedFunctions.contains(name) {
            add(.parameterizedHelper, name)
        } else if functionNames.contains(name) {
            add(.actionNotOTAAction, name)
        } else if let base = memberCall?.base, isViewChain(base) {
            if !supportedModifiers.contains(name), !Self.ignoredMemberCalls.contains(name) {
                add(.unsupportedModifier, name)
            }
        } else if name.first?.isUppercase == true,
                  !supportedViews.contains(name),
                  !Self.ignoredConstructors.contains(name) {
            add(.unsupportedView, name)
        }
        return .visitChildren
    }

    private func isViewChain(_ expression: ExprSyntax) -> Bool {
        if let reference = expression.as(DeclReferenceExprSyntax.self) {
            return helperNames.contains(reference.baseName.text)
        }
        if expression.is(IfExprSyntax.self) { return true }
        if let call = expression.as(FunctionCallExprSyntax.self) {
            if let reference = call.calledExpression.as(DeclReferenceExprSyntax.self) {
                let name = reference.baseName.text
                return supportedViews.contains(name) || (name.first?.isUppercase == true && !Self.ignoredConstructors.contains(name))
            }
            if let member = call.calledExpression.as(MemberAccessExprSyntax.self), let base = member.base {
                return isViewChain(base)
            }
        }
        if let member = expression.as(MemberAccessExprSyntax.self), let base = member.base {
            return isViewChain(base)
        }
        return false
    }

    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        let name = node.baseName.text
        if storedNames.contains(name) { add(.notOTAState, name) }
        return .visitChildren
    }

    private static let ignoredConstructors: Set<String> = [
        "CGFloat", "Color", "Font", "ImageResource", "LocalizedStringKey", "String", "URL",
    ]
    private static let ignoredMemberCalls: Set<String> = [
        "map", "compactMap", "filter", "sorted", "enumerated", "contains", "joined",
    ]
}
