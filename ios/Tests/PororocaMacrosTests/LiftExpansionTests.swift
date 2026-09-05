#if os(macOS)
import SwiftParser
import SwiftSyntax
import XCTest
@testable import PororocaMacros

final class LiftExpansionTests: XCTestCase {
    func testMinimalStackTokensLocalizationAndStateInterpolation() throws {
        let lifted = try lift(
            """
            @Updatable("sample", colors: "Palette", spaces: "Space", radii: "Radius", strings: "L10n.t")
            struct Sample {
                @OTAState var name: String
                var content: some View {
                    VStack(spacing: Space.md) {
                        Text(L10n.t("hello"))
                        Text("Hi \\(name)").foregroundStyle(Palette.text)
                    }
                }
            }
            """
        )
        XCTAssertTrue(lifted.root.contains("PororocaDSL.VStack(spacing: .space(\"md\"))"))
        XCTAssertTrue(lifted.root.contains("PororocaDSL.Text(Str.localized(\"hello\"))"))
        XCTAssertTrue(lifted.root.contains(#"PororocaDSL.Text(Str.expr(.concat([.literal(.string("Hi ")), .state("name")])))"#))
        XCTAssertEqual(lifted.colorTokens, ["text"])
        XCTAssertEqual(lifted.spaceTokens, ["md"])
    }

    func testIfAndButtonAction() throws {
        let lifted = try lift(
            """
            struct Sample {
                @OTAState var loading: Bool
                @OTAAction func purchase() {}
                var content: some View {
                    VStack {
                        if loading { ProgressView() } else { Button { purchase() } label: { Text("Buy") } }
                    }
                }
            }
            """
        )
        XCTAssertTrue(lifted.root.contains("PororocaDSL.If(state.loading)"))
        XCTAssertTrue(lifted.root.contains("PororocaDSL.Button(__PororocaAction.purchase)"))
    }

    func testZeroArgumentComputedViewIsInlined() throws {
        let lifted = try lift(
            """
            struct Sample {
                var content: some View { VStack { title } }
                private var title: some View { Text("Title") }
            }
            """
        )
        XCTAssertTrue(lifted.root.contains("PororocaDSL.Text(\"Title\")"))
    }

    func testTernaryAndForEachStateArray() throws {
        let lifted = try lift(
            """
            struct Sample {
                @OTAState var enabled: Bool
                @OTAState var items: [Item]
                var content: some View {
                    VStack {
                        enabled ? Text("On") : Text("Off")
                        ForEach(items, id: \\.id) { item in Text(item.title) }
                    }
                }
            }
            """
        )
        XCTAssertTrue(lifted.root.contains("PororocaDSL.If(state.enabled)"))
        XCTAssertTrue(lifted.root.contains("PororocaDSL.ForEach(state.items, key: \"id\")"))
        XCTAssertTrue(lifted.root.contains("Expr.item(\"title\")"))
    }

    private func lift(_ source: String) throws -> LiftedView {
        let file = Parser.parse(source: source)
        let structure = file.statements.compactMap { $0.item.as(StructDeclSyntax.self) }.first!
        return try ViewLifter(
            declaration: structure,
            options: .init(screen: "sample", colors: "Palette", spaces: "Space", radii: "Radius", strings: "L10n.t")
        ).lift()
    }
}
#endif
