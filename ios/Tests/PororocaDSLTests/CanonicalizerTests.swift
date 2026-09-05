import PororocaDSL
import XCTest

final class CanonicalizerTests: XCTestCase {
    private let red = ColorValue.hex(HexColor("#FF0000")!)

    func testBackgroundThenPaddingWraps() {
        let node = Text("Hi").background(.color(red)).padding(.all, .points(8)).node
        guard case let .box(child) = node.kind else { return XCTFail("expected box") }
        XCTAssertEqual(node.mod?.padding, [.init(edges: .all, value: .points(8))])
        XCTAssertEqual(child.mod?.background, .color(red))
    }

    func testPaddingThenBackgroundStaysOnNode() {
        let node = Text("Hi").padding(.all, .points(8)).background(.color(red)).node
        guard case .text = node.kind else { return XCTFail("expected text") }
        XCTAssertEqual(node.mod?.padding.count, 1)
        XCTAssertEqual(node.mod?.background, .color(red))
    }

    func testNonOverlappingPaddingStaysOnNode() {
        let node = Text("Hi").padding(.horizontal, .points(8)).padding(.bottom, .points(4)).node
        guard case .text = node.kind else { return XCTFail("expected text") }
        XCTAssertEqual(node.mod?.padding.count, 2)
    }

    func testOverlappingPaddingWraps() {
        let node = Text("Hi").padding(.all, .points(8)).padding(.horizontal, .points(4)).node
        guard case let .box(child) = node.kind else { return XCTFail("expected box") }
        XCTAssertEqual(node.mod?.padding.first?.edges, .horizontal)
        XCTAssertEqual(child.mod?.padding.first?.edges, .all)
    }

    func testFrameThenBackgroundWraps() {
        let node = Text("Hi").frame(width: .points(100)).background(.color(red)).node
        guard case let .box(child) = node.kind else { return XCTFail("expected box") }
        XCTAssertEqual(node.mod?.background, .color(red))
        XCTAssertEqual(child.mod?.frame?.width, .points(100))
    }
}
