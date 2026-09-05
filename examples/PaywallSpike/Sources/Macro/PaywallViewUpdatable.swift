// Macro-adapted copy for the isolated spike.
// Origin: trainer-gym-ai/apps/mobile/Packages/Modules/Sources/Features/Paywall/PaywallView.swift

import SwiftUI
import Pororoca

enum Localization {
    @MainActor static func t(_ key: String) -> String { PaywallStrings.value(key) }
}

@MainActor
@Updatable("paywall", colors: "AppColors", spaces: "AppSpacing", radii: "AppRadius", strings: "Localization.t")
struct PaywallViewUpdatable: View {
    @OTAState var phase: String
    @OTAState var failureReason: String?
    @OTAState var displayPrice: String?
    @OTAState var canDismiss: Bool
    var onAction: (String) -> Void

    init(viewModel: PaywallViewModelStub, onAction: @escaping (String) -> Void = { _ in }) {
        phase = viewModel.phase.rawValue
        failureReason = viewModel.failureReason
        displayPrice = viewModel.displayPrice
        canDismiss = viewModel.canDismiss
        self.onAction = onAction
    }

    @OTAAction func purchase() { onAction("purchase") }
    @OTAAction func restore() { onAction("restore") }
    @OTAAction func redeemCode() { onAction("redeemCode") }
    @OTAAction func dismiss() { onAction("dismiss") }
    @OTAAction func openPrivacy() { onAction("openPrivacy") }
    @OTAAction func openTerms() { onAction("openTerms") }

    var content: some View {
        ZStack {
            Rectangle().fill(AppColors.background).ignoresSafeArea()
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    hero
                    featureList
                    pricingSection
                    legalSection
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxl)
            }
            if canDismiss { closeButton }
        }
    }

    private var hero: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(colors: [AppColors.primary, AppColors.primary.opacity(0.65), AppColors.background], startPoint: .top, endPoint: .bottom))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .frame(height: 260)
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles").font(.system(size: 44, weight: .semibold)).foregroundStyle(AppColors.text).padding(.top, AppSpacing.lg)
                Text(Localization.t("appName")).font(.system(size: 28, weight: .bold)).foregroundStyle(AppColors.text)
                Text(Localization.t("slogan")).font(.system(size: 16, weight: .medium)).foregroundStyle(AppColors.text.opacity(0.9)).multilineTextAlignment(.center).padding(.horizontal, AppSpacing.md).padding(.bottom, AppSpacing.lg)
            }
        }
        .frame(height: 260)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            feature1
            feature2
            feature3
            feature4
            feature5
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    private var feature1: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: "brain.head.profile").font(.system(size: 20, weight: .semibold)).foregroundStyle(AppColors.primary).frame(width: 28, height: 28)
            Text(Localization.t("paywallHero1")).font(.system(size: 16, weight: .medium)).foregroundStyle(AppColors.text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
    private var feature2: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: "figure.strengthtraining.traditional").font(.system(size: 20, weight: .semibold)).foregroundStyle(AppColors.primary).frame(width: 28, height: 28)
            Text(Localization.t("paywallHero2")).font(.system(size: 16, weight: .medium)).foregroundStyle(AppColors.text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
    private var feature3: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 20, weight: .semibold)).foregroundStyle(AppColors.primary).frame(width: 28, height: 28)
            Text(Localization.t("paywallHero3")).font(.system(size: 16, weight: .medium)).foregroundStyle(AppColors.text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
    private var feature4: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: "bell.badge").font(.system(size: 20, weight: .semibold)).foregroundStyle(AppColors.primary).frame(width: 28, height: 28)
            Text(Localization.t("paywallHero4")).font(.system(size: 16, weight: .medium)).foregroundStyle(AppColors.text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
    private var feature5: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: "lock.shield").font(.system(size: 20, weight: .semibold)).foregroundStyle(AppColors.primary).frame(width: 28, height: 28)
            Text(Localization.t("paywallHero5")).font(.system(size: 16, weight: .medium)).foregroundStyle(AppColors.text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var pricingSection: some View {
        VStack(spacing: AppSpacing.md) {
            if phase == "failed" { errorCard }
            Button { purchase() } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.full).fill(AppColors.primary)
                    if phase == "purchasing" {
                        ProgressView().tint(AppColors.text)
                    } else {
                        Text("\(Localization.t("paywallUnlock")) — \(displayPrice ?? "")").font(.system(size: 17, weight: .semibold)).foregroundStyle(AppColors.text).padding(.horizontal, AppSpacing.md).lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56)
            }
            .buttonStyle(.plain)
            Button { restore() } label: { Text(Localization.t("paywallRestore")).font(.system(size: 16, weight: .medium)).foregroundStyle(AppColors.textSecondary).frame(maxWidth: .infinity).padding(.vertical, AppSpacing.sm) }
                .buttonStyle(.plain)
            Button { redeemCode() } label: { Text(Localization.t("paywallRedeemCode")).font(.system(size: 14, weight: .medium)).foregroundStyle(AppColors.textSecondary).frame(maxWidth: .infinity).padding(.vertical, AppSpacing.xs) }
                .buttonStyle(.plain)
        }
    }

    private var legalSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Text(Localization.t("paywallLegalOneTime")).font(.system(size: 12)).foregroundStyle(AppColors.textSecondary).multilineTextAlignment(.center)
            HStack(spacing: AppSpacing.md) {
                Text(Localization.t("privacyPolicyLabel"))
                Text("·").foregroundStyle(AppColors.textSecondary)
                Text(Localization.t("termsOfService"))
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppColors.info)
        }
    }

    private var errorCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(Localization.t("paywallLoadErrorTitle")).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppColors.text)
            Text(Localization.t("paywallLoadErrorBody")).font(.system(size: 13)).foregroundStyle(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
            Text(failureReason ?? "").font(.system(size: 11, design: .monospaced)).foregroundStyle(AppColors.textSecondary.opacity(0.7)).lineLimit(2)
            Text(Localization.t("tryAgain")).font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColors.primary).padding(.vertical, AppSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundStyle(AppColors.text.opacity(0.7)) }
                    .buttonStyle(.plain)
                    .padding(AppSpacing.md)
            }
            Spacer()
        }
    }
}
