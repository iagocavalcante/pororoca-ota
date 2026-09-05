import Observation

enum PaywallPhase: String, CaseIterable, Identifiable {
    case ready, purchasing, failed
    var id: String { rawValue }
}

@MainActor @Observable
final class PaywallViewModelStub {
    var phase: PaywallPhase
    var displayPrice: String
    var failureReason: String
    var canDismiss: Bool
    var isPro: Bool

    init(
        phase: PaywallPhase = .ready,
        displayPrice: String = "R$ 29,90",
        failureReason: String = "StoreKit test failure",
        canDismiss: Bool = true,
        isPro: Bool = false
    ) {
        self.phase = phase
        self.displayPrice = displayPrice
        self.failureReason = failureReason
        self.canDismiss = canDismiss
        self.isPro = isPro
    }
}
