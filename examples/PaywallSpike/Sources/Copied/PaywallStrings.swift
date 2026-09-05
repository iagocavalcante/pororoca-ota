// Extracted for the isolated spike.
// Origin: trainer-gym-ai/apps/mobile/Packages/Modules/Sources/Localization/Localization.swift

import Pororoca

@MainActor
struct PaywallStrings: Localizer {
    init() {}
    static var language = "pt-BR"

    static let ptBR: [String: String] = [
        "appName": "Trainer Gym AI",
        "slogan": "Seu assistente virtual para treinamentos físicos",
        "paywallHero1": "Treinos por IA que se adaptam a você",
        "paywallHero2": "Acompanhe cada série, treino e dia",
        "paywallHero3": "Gráficos de progresso, ofensivas e PRs",
        "paywallHero4": "Lembretes inteligentes adaptados à sua rotina",
        "paywallHero5": "Privado por padrão — seus dados ficam no aparelho",
        "paywallUnlock": "Desbloquear",
        "paywallRestore": "Restaurar Compras",
        "paywallRedeemCode": "Tem um código?",
        "paywallLegalOneTime": "Pagamento único. Sem assinatura.",
        "privacyPolicyLabel": "Política de Privacidade",
        "termsOfService": "Termos de Serviço",
        "paywallLoadErrorTitle": "Não foi possível carregar a opção de compra",
        "paywallLoadErrorBody": "Verifique sua conexão e tente novamente.",
        "tryAgain": "Tentar Novamente",
    ]

    static let en: [String: String] = [
        "appName": "Trainer Gym AI",
        "slogan": "Your virtual assistant for physical training",
        "paywallHero1": "Personalized AI workouts that adapt to you",
        "paywallHero2": "Track every set, every workout, every day",
        "paywallHero3": "Progress charts, streaks, and PR tracking",
        "paywallHero4": "Smart reminders that learn your schedule",
        "paywallHero5": "Private by design — your data stays on device",
        "paywallUnlock": "Unlock",
        "paywallRestore": "Restore Purchases",
        "paywallRedeemCode": "Have a code?",
        "paywallLegalOneTime": "One-time purchase. No subscriptions.",
        "privacyPolicyLabel": "Privacy Policy",
        "termsOfService": "Terms of Service",
        "paywallLoadErrorTitle": "Couldn't load purchase options",
        "paywallLoadErrorBody": "Check your connection and try again.",
        "tryAgain": "Try Again",
    ]

    static func value(_ key: String) -> String { (language == "pt-BR" ? ptBR : en)[key] ?? key }
    func string(for key: String) -> String { Self.value(key) }
}
