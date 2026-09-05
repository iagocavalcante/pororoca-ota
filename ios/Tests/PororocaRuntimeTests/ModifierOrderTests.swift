#if os(iOS)
import SnapshotTesting
import SwiftUI
import XCTest
import PororocaDocument
import PororocaExpr
@testable import PororocaRuntime

@MainActor
final class ModifierOrderTests: XCTestCase {
    func testNestedBackgroundHugsText() {
        let red = Paint.color(.hex(HexColor("#FF3344")!))
        let node = Node(.box(child: Node(.text(value: .literal("Order")), mod: .init(background: red))), mod: .init(padding: [.init(edges: .all, value: .points(24))]))
        assertOrder(node, named: "box-padding-text-background")
    }

    func testCanonicalBackgroundIncludesPadding() {
        let red = Paint.color(.hex(HexColor("#FF3344")!))
        let node = Node(.text(value: .literal("Order")), mod: .init(padding: [.init(edges: .all, value: .points(24))], background: red))
        assertOrder(node, named: "text-padding-background")
    }

    private func assertOrder(_ node: Node, named name: String) {
        let host = ScreenHost(capabilities: .init(runtime: "1"), tokens: DictionaryTokenResolver(), localizer: DictionaryLocalizer())
        for (suffix, style) in [("light", UIUserInterfaceStyle.light), ("dark", .dark)] {
            let view = NodeView(node: node, state: StateBox(), local: .constant([:]), strings: [:], host: host) { _, _ in }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
            let traits = UITraitCollection(traitsFrom: [UITraitCollection(displayScale: 1), UITraitCollection(userInterfaceStyle: style)])
            assertSnapshot(of: view, as: .image(layout: .fixed(width: 390, height: 844), traits: traits), named: "\(name)-\(suffix)")
        }
    }
}
#endif
