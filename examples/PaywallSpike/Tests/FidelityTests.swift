import SnapshotTesting
import SwiftUI
import XCTest
@testable import PaywallSpike

@MainActor
final class FidelityTests: XCTestCase {
    func testReadyPhoneAndTabletLightDark() {
        for (device, width, height) in [("iphone", 402.0, 874.0), ("ipad", 1032.0, 1376.0)] {
            for (suffix, style) in [("light", UIUserInterfaceStyle.light), ("dark", .dark)] {
                assertFidelity(phase: .ready, size: CGSize(width: width, height: height), style: style, named: "ready-\(device)-\(suffix)")
            }
        }
    }

    func testPurchasingAndFailedOnPhone() {
        for phase in [PaywallPhase.purchasing, .failed] {
            assertFidelity(phase: phase, size: CGSize(width: 402, height: 874), style: .dark, named: "\(phase.rawValue)-iphone-dark")
        }
    }

    private func assertFidelity(phase: PaywallPhase, size: CGSize, style: UIUserInterfaceStyle, named name: String) {
        let model = PaywallViewModelStub(phase: phase)
        let traits = UITraitCollection(traitsFrom: [UITraitCollection(displayScale: 1), UITraitCollection(userInterfaceStyle: style)])
        let strategy = Snapshotting<AnyView, UIImage>.image(
            precision: 0.99,
            perceptualPrecision: 0.98,
            layout: .fixed(width: size.width, height: size.height),
            traits: traits
        )
        assertSnapshot(of: AnyView(PaywallView(viewModel: model)), as: strategy, named: name)
        assertSnapshot(of: AnyView(PaywallDocumentView(source: .embedded(PaywallScreen.document), viewModel: model)), as: strategy, named: name)
        assertSnapshot(of: AnyView(PaywallViewUpdatable(viewModel: model)), as: strategy, named: name)
    }
}
