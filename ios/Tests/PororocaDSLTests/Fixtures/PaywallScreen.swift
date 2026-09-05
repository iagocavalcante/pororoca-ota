import PororocaDSL

enum PaywallScreen {
    struct State: ScreenState {
        static let schema: [String: StateType] = [
            "phase": .string,
            "displayPrice": .optionalString,
            "isPro": .bool,
            "canDismiss": .bool,
        ]
    }

    enum Action: String, ScreenAction {
        case purchase, restore, redeemCode, dismiss
    }

    static let document = Screen(
        "paywall",
        state: State.self,
        actions: Action.self,
        localDefaults: ["selectedPlan": "lifetime"]
    ) { state, local in
        ZStack {
            Rectangle().fill(.color(.token(name: "background", opacity: nil)))
            VStack(spacing: .token("lg"), alignment: .center) {
                Text(Str.localized("appName"))
                    .font(.token("title"))
                    .foreground(.token(name: "text", opacity: nil))
                Text(Str.localized("slogan"))
                Button(Action.purchase, args: ["plan": local.selectedPlan]) {
                    Text("\(t("paywallUnlock")) — \(state.displayPrice ?? "…")")
                }
                If(state.phase == "ready") {
                    Text("Ready")
                }
            }
            .padding(.all, .token("xl"))
        }
    }
}
