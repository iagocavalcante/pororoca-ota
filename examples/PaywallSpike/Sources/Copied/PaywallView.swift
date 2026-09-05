// Adapted copy for the isolated spike; StoreKit, analytics and app links are stubbed.
// Origin: trainer-gym-ai/apps/mobile/Packages/Modules/Sources/Features/Paywall/PaywallView.swift

import SwiftUI

@MainActor
struct PaywallView: View {
    let viewModel: PaywallViewModelStub
    var onAction: (String) -> Void = { _ in }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
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
            .defaultScrollAnchor(.top)
            if viewModel.canDismiss { closeButton }
        }
    }

    private var hero: some View {
        ZStack {
            LinearGradient(colors: [AppColors.primary, AppColors.primary.opacity(0.65), AppColors.background], startPoint: .top, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                    .padding(.top, AppSpacing.lg)
                Text(PaywallStrings.value("appName"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppColors.text)
                Text(PaywallStrings.value("slogan"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.text.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.lg)
            }
        }
        .frame(height: 260)
    }

    private var featureList: some View {
        let items = [
            ("brain.head.profile", "paywallHero1"),
            ("figure.strengthtraining.traditional", "paywallHero2"),
            ("chart.line.uptrend.xyaxis", "paywallHero3"),
            ("bell.badge", "paywallHero4"),
            ("lock.shield", "paywallHero5"),
        ]
        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach(items, id: \.1) { icon, key in featureRow(icon: icon, key: key) }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private func featureRow(icon: String, key: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColors.primary)
                .frame(width: 28, height: 28)
            Text(PaywallStrings.value(key))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var pricingSection: some View {
        VStack(spacing: AppSpacing.md) {
            if viewModel.phase == .failed { errorCard }
            Button { onAction("purchase") } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.full, style: .continuous).fill(AppColors.primary)
                    if viewModel.phase == .purchasing {
                        ProgressView().tint(AppColors.text)
                    } else {
                        Text("\(PaywallStrings.value("paywallUnlock")) — \(viewModel.displayPrice)")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppColors.text)
                            .padding(.horizontal, AppSpacing.md)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56)
            }
            .buttonStyle(.plain)
            Button { onAction("restore") } label: {
                Text(PaywallStrings.value("paywallRestore"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
            }
            .buttonStyle(.plain)
            Button { onAction("redeemCode") } label: {
                Text(PaywallStrings.value("paywallRedeemCode"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xs)
            }
            .buttonStyle(.plain)
        }
    }

    private var legalSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Text(PaywallStrings.value("paywallLegalOneTime"))
                .font(.system(size: 12))
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: AppSpacing.md) {
                Text(PaywallStrings.value("privacyPolicyLabel"))
                Text("·").foregroundStyle(AppColors.textSecondary)
                Text(PaywallStrings.value("termsOfService"))
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppColors.info)
        }
    }

    private var errorCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(PaywallStrings.value("paywallLoadErrorTitle")).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppColors.text)
            Text(PaywallStrings.value("paywallLoadErrorBody")).font(.system(size: 13)).foregroundStyle(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
            Text(viewModel.failureReason).font(.system(size: 11, design: .monospaced)).foregroundStyle(AppColors.textSecondary.opacity(0.7)).lineLimit(2)
            Text(PaywallStrings.value("tryAgain")).font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColors.primary).padding(.vertical, AppSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { onAction("dismiss") } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundStyle(AppColors.text.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(AppSpacing.md)
            }
            Spacer()
        }
    }
}
