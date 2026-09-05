// Adapted copy for the isolated spike.
// Origin: trainer-gym-ai/apps/mobile/Packages/Modules/Sources/Theme/Theme.swift

import SwiftUI

enum AppColors {
    static let background = Color(hex: "#0A0A0C")
    static let surface = Color(hex: "#161618")
    static let primary = Color(hex: "#8e44ad")
    static let accent = Color(hex: "#FF9500")
    static let text = Color(hex: "#ffffff")
    static let textSecondary = Color(hex: "#8E8E93")
    static let info = Color(hex: "#3498db")
    static let danger = Color(hex: "#e74c3c")
}

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 40
}

enum AppRadius {
    static let md: CGFloat = 12
    static let lg: CGFloat = 20
    static let full: CGFloat = 50
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.dropFirst(), radix: 16) ?? 0
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255,
            opacity: 1
        )
    }
}
