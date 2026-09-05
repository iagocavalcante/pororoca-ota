import SwiftUI
import Pororoca

@MainActor
struct PaywallDocumentView: View {
    let source: DocumentSource
    let viewModel: PaywallViewModelStub
    var onAction: (String) -> Void = { _ in }

    var body: some View {
        OTAScreen(source: source, state: snapshot, host: PaywallHost.value) { name, _ in onAction(name) }
    }

    private var snapshot: StateSnapshot {
        StateSnapshot([
            "phase": .string(viewModel.phase.rawValue),
            "displayPrice": .string(viewModel.displayPrice),
            "failureReason": .string(viewModel.failureReason),
            "canDismiss": .bool(viewModel.canDismiss),
            "isPro": .bool(viewModel.isPro),
        ])
    }
}

@MainActor
enum PaywallHost {
    static let value = ScreenHost(
        capabilities: HostCapabilities(PaywallScreen.document.requires),
        tokens: DictionaryTokenResolver(
            colors: [
                "background": AppColors.background, "surface": AppColors.surface,
                "primary": AppColors.primary, "text": AppColors.text,
                "accent": AppColors.accent,
                "textSecondary": AppColors.textSecondary, "info": AppColors.info,
                "danger": AppColors.danger,
            ],
            spaces: ["xs": AppSpacing.xs, "sm": AppSpacing.sm, "md": AppSpacing.md, "lg": AppSpacing.lg, "xl": AppSpacing.xl, "xxl": AppSpacing.xxl],
            radii: ["md": AppRadius.md, "lg": AppRadius.lg, "full": AppRadius.full]
        ),
        localizer: PaywallStrings()
    )
}

enum PaywallDocumentFile {
    static func bootstrap() throws -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = directory.appendingPathComponent("paywall.ios.json")
        if !FileManager.default.fileExists(atPath: url.path) {
            try DocumentCodec.encode(PaywallScreen.document).write(to: url, options: .atomic)
        }
        return url
    }
}

#Preview("Document paywall") {
    PaywallDocumentView(
        source: .embedded(PaywallScreen.document),
        viewModel: PaywallViewModelStub()
    )
    .preferredColorScheme(.dark)
}
