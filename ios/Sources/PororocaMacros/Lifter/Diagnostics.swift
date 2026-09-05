import SwiftDiagnostics
import SwiftSyntax

enum LiftDiagnostic: String, DiagnosticMessage {
    case notOTAState
    case unsupportedView
    case unsupportedModifier
    case unsupportedControlFlow
    case parameterizedHelper
    case actionNotOTAAction
    case unknownTokenNamespace
    case missingContent
    case invalidDeclaration

    var message: String {
        switch self {
        case .notOTAState: "state referenced by an updatable view must be marked @OTAState"
        case .unsupportedView: "this view is not supported by @Updatable"
        case .unsupportedModifier: "this modifier is not supported by @Updatable"
        case .unsupportedControlFlow: "use if/else or a ternary expression in @Updatable content"
        case .parameterizedHelper: "convert this helper to a zero-argument computed property"
        case .actionNotOTAAction: "actions referenced by an updatable view must be marked @OTAAction"
        case .unknownTokenNamespace: "use the color, spacing, or radius namespace declared by @Updatable"
        case .missingContent: "@Updatable requires a computed `content` property"
        case .invalidDeclaration: "@Updatable can only be attached to a struct"
        }
    }

    var diagnosticID: MessageID { .init(domain: "dev.pororoca.macros", id: rawValue) }
    var severity: DiagnosticSeverity { .error }
}

struct LiftFailure: Error {
    let diagnostic: LiftDiagnostic
    let node: Syntax
}
