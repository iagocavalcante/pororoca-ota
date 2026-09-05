import Pororoca

enum PaywallScreen {
    struct State: ScreenState {
        static let schema: [String: StateType] = [
            "phase": .string, "displayPrice": .optionalString, "failureReason": .optionalString,
            "canDismiss": .bool, "isPro": .bool,
        ]
    }

    enum Action: String, ScreenAction { case purchase, restore, redeemCode, dismiss, retry }

    static let document = Screen("paywall", state: State.self, actions: Action.self) { state, _ in
        ZStack {
            Rectangle().fill(.color(.color("background"))).ignoresSafeArea()
            ScrollView {
                VStack(spacing: .space("xl")) {
                    hero
                    VStack(spacing: .space("md"), alignment: .leading) {
                        featureRow(icon: "brain.head.profile", key: "paywallHero1")
                        featureRow(icon: "figure.strengthtraining.traditional", key: "paywallHero2")
                        featureRow(icon: "chart.line.uptrend.xyaxis", key: "paywallHero3")
                        featureRow(icon: "bell.badge", key: "paywallHero4")
                        featureRow(icon: "lock.shield", key: "paywallHero5")
                    }
                    .padding(.all, .space("md"))
                    .background(.color(.color("surface")))
                    .cornerRadius(.radius("md"))
                    VStack(spacing: .space("md")) {
                        If(state.phase == "failed") { errorCard(state: state) }
                        Button(Action.purchase) {
                            ZStack {
                                RoundedRectangle(cornerRadius: .radius("full")).fill(.color(.color("primary")))
                                If(state.phase == "purchasing") {
                                    Progress(tint: .color("text"))
                                } else: {
                                    Text("\(t("paywallUnlock")) — \(state.displayPrice ?? "")")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foreground(.color("text"))
                                        .padding(.horizontal, .space("md"))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: .points(56), maxHeight: .points(56))
                        }
                        Button(Action.restore) {
                            Text(Str.localized("paywallRestore"))
                                .font(.system(size: 16, weight: .medium))
                                .foreground(.color("textSecondary"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, .space("sm"))
                        }
                        Button(Action.redeemCode) {
                            Text(Str.localized("paywallRedeemCode"))
                                .font(.system(size: 14, weight: .medium))
                                .foreground(.color("textSecondary"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, .space("xs"))
                        }
                    }
                    VStack(spacing: .space("sm")) {
                        Text(Str.localized("paywallLegalOneTime"))
                            .font(.system(size: 12))
                            .foreground(.color("textSecondary"))
                            .multilineAlignment(.center)
                        HStack(spacing: .space("md")) {
                            Text(Str.localized("privacyPolicyLabel"))
                            Text("·").foreground(.color("textSecondary"))
                            Text(Str.localized("termsOfService"))
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foreground(.color("info"))
                    }
                }
                .padding(.horizontal, .space("lg"))
                .padding(.bottom, .space("xxl"))
            }
            If(state.canDismiss) {
                VStack {
                    HStack {
                        Spacer()
                        Button(Action.dismiss) {
                            Icon("xmark.circle.fill", size: 28).foreground(.color("text", opacity: 0.7))
                        }
                        .padding(.all, .space("md"))
                    }
                    Spacer()
                }
            }
        }
    }

    private static var hero: DSLNode {
        ZStack {
            Rectangle()
                .fill(.gradient(.linear(.init(
                    colors: [.color("primary"), .color("primary", opacity: 0.65), .color("background")],
                    start: .top, end: .bottom
                ))))
                .cornerRadius(.radius("lg"))
                .frame(height: .points(260))
            VStack(spacing: .space("sm")) {
                Icon("sparkles", size: 44, weight: .semibold)
                    .foreground(.color("text"))
                    .padding(.top, .space("lg"))
                Text(Str.localized("appName"))
                    .font(.system(size: 28, weight: .bold))
                    .foreground(.color("text"))
                Text(Str.localized("slogan"))
                    .font(.system(size: 16, weight: .medium))
                    .foreground(.color("text", opacity: 0.9))
                    .multilineAlignment(.center)
                    .padding(.horizontal, .space("md"))
                    .padding(.bottom, .space("lg"))
            }
        }
        .frame(height: .points(260))
    }

    private static func featureRow(icon: String, key: String) -> DSLNode {
        HStack(spacing: .space("md"), alignment: .top) {
            Icon(icon, size: 20, weight: .semibold)
                .foreground(.color("primary"))
                .frame(width: .points(28), height: .points(28))
            Text(Str.localized(key))
                .font(.system(size: 16, weight: .medium))
                .foreground(.color("text"))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: .points(0))
        }
    }

    private static func errorCard(state: StateRef<State>) -> DSLNode {
        VStack(spacing: .space("sm"), alignment: .leading) {
            Text(Str.localized("paywallLoadErrorTitle")).font(.system(size: 15, weight: .semibold)).foreground(.color("text"))
            Text(Str.localized("paywallLoadErrorBody")).font(.system(size: 13)).foreground(.color("textSecondary")).fixedSize(horizontal: false, vertical: true)
            Text(state.failureReason ?? "").font(.system(size: 11, design: .monospaced)).foreground(.color("textSecondary", opacity: 0.7)).lineLimit(2)
            Text(Str.localized("tryAgain")).font(.system(size: 14, weight: .semibold)).foreground(.color("primary")).padding(.vertical, .space("xs"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.all, .space("md"))
        .background(.color(.color("surface")))
        .cornerRadius(.radius("md"))
    }
}
