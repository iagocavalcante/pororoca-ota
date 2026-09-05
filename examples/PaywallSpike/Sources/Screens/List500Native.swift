import SwiftUI
import Pororoca

struct List500Native: View {
    let highlight: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.sm) {
                ForEach(List500Screen.items) { item in
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppColors.primary)
                            .frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(item.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(AppColors.text)
                            Text(item.subtitle).font(.system(size: 13)).foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer(minLength: 0)
                        if highlight { Image(systemName: "sparkles").font(.system(size: 12)).foregroundStyle(AppColors.accent) }
                        Text(item.value).font(.system(size: 14, weight: .medium, design: .monospaced)).foregroundStyle(AppColors.text)
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.background)
        .defaultScrollAnchor(.top)
    }
}

@MainActor
struct List500Document: View {
    let highlight: Bool

    var body: some View {
        OTAScreen(
            source: .embedded(List500Screen.document),
            state: StateSnapshot(["items": List500Screen.valueItems, "highlight": .bool(highlight)]),
            host: List500Host.value
        )
    }
}
