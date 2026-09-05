#if os(macOS)
import SwiftParser
import SwiftSyntax
import XCTest
@testable import PororocaMacros

final class DiagnosticsTests: XCTestCase {
    func testUnsupportedViewDiagnostic() { assertFailure("Map { Text(\"x\") }", .unsupportedView) }
    func testUnsupportedModifierDiagnostic() { assertFailure("Text(\"x\").blur(radius: 2)", .unsupportedModifier) }
    func testUnsupportedControlFlowDiagnostic() { assertFailure("switch value { default: Text(\"x\") }", .unsupportedControlFlow) }
    func testUnmarkedStateDiagnostic() { assertFailure("if enabled { Text(\"x\") }", .notOTAState) }
    func testUnknownTokenNamespaceDiagnostic() { assertFailure("Text(\"x\").foregroundStyle(Other.text)", .unknownTokenNamespace) }
    func testActionMustBeMarked() { assertFailure("Button { purchase() } label: { Text(\"Buy\") }", .actionNotOTAAction, members: "func purchase() {}") }
    func testParameterizedHelperDiagnostic() { assertFailure("row(value: 1)", .parameterizedHelper, members: "func row(value: Int) -> some View { Text(\"row\") }") }
    func testIfLetDiagnostic() { assertFailure("if let value { Text(value) }", .unsupportedControlFlow) }

    private func assertFailure(_ content: String, _ expected: LiftDiagnostic, members: String = "", file: StaticString = #filePath, line: UInt = #line) {
        let source = "struct Sample { \(members) var content: some View { \(content) } }"
        let syntax = Parser.parse(source: source)
        let structure = syntax.statements.compactMap { $0.item.as(StructDeclSyntax.self) }.first!
        XCTAssertThrowsError(
            try ViewLifter(declaration: structure, options: .init(screen: "x", colors: "Palette", spaces: "Space", radii: "Radius", strings: "L10n.t")).lift(),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual((error as? LiftFailure)?.diagnostic, expected, file: file, line: line)
        }
    }
}
#endif
