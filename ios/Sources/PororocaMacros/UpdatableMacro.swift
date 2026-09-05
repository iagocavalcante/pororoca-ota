import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum UpdatableMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structure = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: Syntax(declaration), message: LiftDiagnostic.invalidDeclaration))
            return []
        }
        guard let options = decode(node) else { return [] }

        do {
            let lifted = try ViewLifter(declaration: structure, options: options).lift()
            return declarations(for: lifted, options: options)
        } catch let failure as LiftFailure {
            context.diagnose(Diagnostic(node: failure.node, message: failure.diagnostic))
            return []
        }
    }

    private static func decode(_ attribute: AttributeSyntax) -> LiftOptions? {
        guard case let .argumentList(arguments) = attribute.arguments else { return nil }
        func string(label: String?) -> String? {
            arguments.first { argument in
                if let label { argument.label?.text == label } else { argument.label == nil }
            }?.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
        }
        guard let screen = string(label: nil), let colors = string(label: "colors"),
              let spaces = string(label: "spaces"), let radii = string(label: "radii"),
              let strings = string(label: "strings") else { return nil }
        return .init(screen: screen, colors: colors, spaces: spaces, radii: radii, strings: strings)
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        [try ExtensionDeclSyntax("extension \(type.trimmed): UpdatableHost {}")]
    }

    private static func declarations(for view: LiftedView, options: LiftOptions) -> [DeclSyntax] {
        let schema = view.state.map { "\(quoted($0.name)): \(stateType($0.type))" }.joined(separator: ", ")
        let stateValues = view.state.map { "\(quoted($0.name)): pororocaValue(\($0.name))" }.joined(separator: ", ")
        let actionDeclaration: String
        if view.actions.isEmpty {
            actionDeclaration = """
            private struct __PororocaAction: ScreenAction {
                let rawValue: String
                init?(rawValue: String) { return nil }
                static let allCases: [__PororocaAction] = []
            }
            """
        } else {
            let cases = view.actions.map { "case \($0)" }.joined(separator: "\n")
            actionDeclaration = """
            private enum __PororocaAction: String, ScreenAction {
                \(cases)
            }
            """
        }
        let actionDispatch = view.actions.map { "case \(quoted($0)): \($0)()" }.joined(separator: "\n")
        let colorValues = view.colorTokens.sorted().map { "\(quoted($0)): \(options.colors).\($0)" }.joined(separator: ", ")
        let spaceValues = view.spaceTokens.sorted().map { "\(quoted($0)): \(options.spaces).\($0)" }.joined(separator: ", ")
        let radiusValues = view.radiusTokens.sorted().map { "\(quoted($0)): \(options.radii).\($0)" }.joined(separator: ", ")

        return [
            """
            private struct __PororocaState: ScreenState {
                static let schema: [String: StateType] = [\(raw: schema)]
            }
            """,
            "\(raw: actionDeclaration)",
            """
            static let __pororocaDocument: Document = PororocaDSL.Screen(\(literal: options.screen), state: __PororocaState.self, actions: __PororocaAction.self) { state, _ in
                \(raw: view.root)
            }
            """,
            """
            var __pororocaState: StateSnapshot {
                StateSnapshot([\(raw: stateValues)])
            }
            """,
            """
            func __pororocaHandle(_ name: String, _ args: [String: Value]) {
                switch name {
                \(raw: actionDispatch)
                default: break
                }
            }
            """,
            """
            static var __pororocaHostEntry: HostManifestEntry {
                HostManifestEntry(screen: \(literal: options.screen), requires: __pororocaDocument.requires)
            }
            """,
            """
            @MainActor static var __pororocaHost: ScreenHost {
                ScreenHost(
                    capabilities: HostCapabilities(__pororocaDocument.requires),
                    tokens: DictionaryTokenResolver(
                        colors: [\(raw: colorValues)],
                        spaces: [\(raw: spaceValues)],
                        radii: [\(raw: radiusValues)]
                    ),
                    localizer: ClosureLocalizer { \(raw: options.strings)($0) }
                )
            }
            """,
            """
            @MainActor var body: some View {
                OTAScreen(source: .embedded(Self.__pororocaDocument), state: __pororocaState, host: Self.__pororocaHost, onAction: __pororocaHandle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            }
            """,
        ]
    }

    private static func stateType(_ type: String) -> String {
        switch type.replacingOccurrences(of: " ", with: "") {
        case "String": ".string"
        case "String?", "Optional<String>": ".optionalString"
        case "Bool": ".bool"
        case "Bool?", "Optional<Bool>": ".optionalBool"
        case "Int", "Double", "Float", "CGFloat": ".number"
        case "Int?", "Double?", "Float?", "CGFloat?": ".optionalNumber"
        default: ".array"
        }
    }
}
