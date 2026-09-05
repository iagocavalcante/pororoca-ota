#if os(macOS)
import SwiftParser
import SwiftSyntax
import XCTest
@testable import PororocaMacros

final class PaywallLiftSyntaxTests: XCTestCase {
    func testPaywallShapedSourceLiftsThroughSharedDSL() throws {
        let source = """
        struct Paywall {
            @OTAState var phase: String
            @OTAState var price: String?
            @OTAAction func purchase() {}
            var content: some View {
                VStack(spacing: Space.md) {
                    if phase == "purchasing" { ProgressView().tint(Palette.text) }
                    else { Button { purchase() } label: { Text("Buy — \\(price ?? "")") } }
                }
                .padding(.horizontal, Space.lg)
            }
        }
        """
        let file = Parser.parse(source: source)
        let structure = file.statements.compactMap { $0.item.as(StructDeclSyntax.self) }.first!
        let lifted = try ViewLifter(
            declaration: structure,
            options: .init(screen: "paywall", colors: "Palette", spaces: "Space", radii: "Radius", strings: "L10n.t")
        ).lift()

        XCTAssertTrue(lifted.root.contains("state.phase == \"purchasing\""))
        XCTAssertTrue(lifted.root.contains("__PororocaAction.purchase"))
        XCTAssertTrue(lifted.root.contains(".coalesce([.state(\"price\")"))
        XCTAssertEqual(lifted.actions, ["purchase"])
    }
}
#endif
