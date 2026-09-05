import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct PororocaPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        UpdatableMacro.self,
        OTAStateMacro.self,
        OTAActionMacro.self,
    ]
}
