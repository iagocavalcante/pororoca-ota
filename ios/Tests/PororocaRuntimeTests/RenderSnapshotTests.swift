#if os(iOS)
import SnapshotTesting
import SwiftUI
import XCTest
import PororocaDocument
import PororocaExpr
@testable import PororocaRuntime

@MainActor
final class RenderSnapshotTests: XCTestCase {
    func testEveryNodeKindInLightAndDark() {
        for (name, node) in nodeSamples { assertLightAndDark(node, named: "node-\(name)") }
    }

    func testEveryModifierInLightAndDark() {
        for (name, props) in modifierSamples {
            assertLightAndDark(Node(.text(value: .literal("Pororoca")), mod: props), named: "modifier-\(name)")
        }
    }

    func testForEachUsesStableKeysAcrossReorder() {
        let first: Value = [["id": "a", "name": "Alpha"], ["id": "b", "name": "Beta"], ["id": "c", "name": "Gamma"]]
        let second: Value = [["id": "c", "name": "Gamma"], ["id": "a", "name": "Alpha"], ["id": "b", "name": "Beta"]]
        let before = runtimeRows(first, key: "id").map(\.id)
        let after = runtimeRows(second, key: "id").map(\.id)
        XCTAssertEqual(Set(before), Set(after))
        XCTAssertEqual(before.count, 3)
        XCTAssertEqual(after, [before[2], before[0], before[1]])
    }

    func testInvalidDocumentIsRejectedBeforeRender() {
        let invalid = Document(
            format: 2,
            screen: "invalid",
            platform: .ios,
            requires: .init(runtime: "1"),
            root: Node(.text(value: .literal("never rendered")))
        )
        XCTAssertEqual(Validator.validate(invalid).map(\.code), [.unsupportedFormat])
    }

    private func assertLightAndDark(_ node: Node, named name: String, file: StaticString = #filePath, testName: String = #function, line: UInt = #line) {
        for (suffix, style) in [("light", UIUserInterfaceStyle.light), ("dark", .dark)] {
            let view = NodeView(node: node, state: state, local: .constant([:]), strings: ["hello": "Localized"], host: host) { _, _ in }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
            let traits = UITraitCollection(traitsFrom: [UITraitCollection(displayScale: 1), UITraitCollection(userInterfaceStyle: style)])
            assertSnapshot(
                of: view,
                as: .image(layout: .fixed(width: 390, height: 844), traits: traits),
                named: "\(name)-\(suffix)",
                file: file,
                testName: testName,
                line: line
            )
        }
    }

    private var host: ScreenHost {
        ScreenHost(
            capabilities: .init(runtime: "1", state: ["show": .bool, "items": .array], actions: ["tap"], slots: ["badge"], tokens: .init(color: ["accent"], space: ["md"], radius: ["card"], font: ["title"]), strings: ["hello"]),
            tokens: DictionaryTokenResolver(colors: ["accent": .orange], spaces: ["md": 12], radii: ["card": 14], fonts: ["title": .headline]),
            localizer: DictionaryLocalizer(["hello": "Localized"]),
            slots: TestSlots()
        )
    }

    private var state: StateBox {
        StateBox(.init([
            "show": true,
            "items": [["id": "a", "name": "Alpha"], ["id": "b", "name": "Beta"], ["id": "c", "name": "Gamma"]],
        ]))
    }

    private var nodeSamples: [(String, Node)] {
        let label = Node(.text(value: .literal("Label")))
        return [
            ("vstack", Node(.vstack(spacing: .points(8), alignment: .leading, children: [label, label]))),
            ("hstack", Node(.hstack(spacing: .points(8), alignment: .center, children: [label, label]))),
            ("zstack", Node(.zstack(alignment: .center, children: [Node(.shape(kind: .circle, cornerRadius: nil, fill: .color(.token(name: "accent", opacity: 0.3)))), label]), mod: .init(frame: .init(width: .points(90), height: .points(90))))),
            ("box", Node(.box(child: label))),
            ("spacer", Node(.hstack(spacing: nil, alignment: nil, children: [label, Node(.spacer(minLength: .points(30))), label]))),
            ("scroll", Node(.scroll(axis: .horizontal, child: Node(.hstack(spacing: .points(24), alignment: nil, children: [label, label, label]))), mod: .init(frame: .init(width: .points(140), height: .points(50))))),
            ("lazycolumn", Node(.lazycolumn(spacing: .points(8), children: [label, label, label]), mod: .init(frame: .init(width: .points(140), height: .points(100))))),
            ("text", Node(.text(value: .localized("hello")))),
            ("icon", Node(.icon(sf: "sparkles", material: nil, size: 34, weight: .bold))),
            ("image", Node(.image(source: .bundled("missing-test-image"), contentMode: .fit), mod: .init(frame: .init(width: .points(60), height: .points(60))))),
            ("shape", Node(.shape(kind: .rounded, cornerRadius: .token("card"), fill: .color(.token(name: "accent", opacity: nil))), mod: .init(frame: .init(width: .points(100), height: .points(60))))),
            ("divider", Node(.divider, mod: .init(frame: .init(width: .points(140))))),
            ("progress", Node(.progress(tint: .token(name: "accent", opacity: nil)))),
            ("button", Node(.button(action: .init(name: "tap"), role: nil, label: label))),
            ("if", Node(.if(cond: .state("show"), then: label, else: Node(.text(value: .literal("Hidden")))))),
            ("foreach", Node(.foreach(items: .state("items"), key: "id", template: Node(.text(value: .expr(.item("name"))))))),
            ("slot", Node(.slot(name: "badge", props: ["title": .string(.literal("Host slot"))]))),
        ]
    }

    private var modifierSamples: [(String, ModifierProps)] {
        let red = ColorValue.hex(HexColor("#FF3344")!)
        return [
            ("font", .init(font: .system(.init(size: 28, weight: .bold, design: .rounded)))),
            ("foreground", .init(foreground: red)),
            ("lineLimit", .init(lineLimit: 1, frame: .init(width: .points(30)))),
            ("multilineAlignment", .init(multilineAlignment: .trailing, frame: .init(width: .points(120)))),
            ("minimumScaleFactor", .init(minimumScaleFactor: 0.4, frame: .init(width: .points(45)))),
            ("fixedSize", .init(fixedSize: .init(horizontal: true, vertical: true))),
            ("padding", .init(padding: [.init(edges: .all, value: .token("md"))])),
            ("background", .init(background: .color(red))),
            ("frame", .init(frame: .init(width: .points(160), height: .points(70), alignment: .bottomTrailing))),
            ("cornerRadius", .init(background: .color(red), cornerRadius: .init(radius: .token("card"), style: .continuous))),
            ("clip", .init(background: .color(red), frame: .init(width: .points(100), height: .points(50)), clip: .capsule)),
            ("border", .init(padding: [.init(edges: .all, value: .points(8))], border: .init(color: red, width: 3))),
            ("shadow", .init(padding: [.init(edges: .all, value: .points(8))], background: .color(.hex(HexColor("#FFFFFF")!)), shadow: .init(color: red, radius: 8, x: 3, y: 4))),
            ("opacity", .init(foreground: red, opacity: 0.35)),
            ("disabled", .init(disabled: .literal(true))),
            ("hidden", .init(hidden: .literal(true))),
            ("accessibilityLabel", .init(accessibilityLabel: .literal("Accessible Pororoca"))),
            ("ignoresSafeArea", .init(background: .color(red), ignoresSafeArea: .all)),
            ("id", .init(id: "stable-id")),
        ]
    }
}

private struct TestSlots: SlotRegistry {
    func view(named name: String, props: [String: Value]) -> AnyView? {
        guard name == "badge", case let .string(title)? = props["title"] else { return nil }
        return AnyView(Text(title).padding(8).background(.purple).clipShape(Capsule()))
    }
}
#endif
