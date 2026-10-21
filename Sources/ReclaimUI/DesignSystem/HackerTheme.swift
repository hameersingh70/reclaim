// HackerTheme.swift
// ReclaimUI/DesignSystem
//
// Neo-Brutalist Retro Pop Tech Theme:
// Warm retro cream canvas, crisp high-contrast black borders,
// unblurred hard drop shadows, and vibrant pop accents (Coral, Amber, Mint, Cobalt).

import SwiftUI

public struct HackerTheme: Theme {
    public let name = "Retro Tech"
    // Warm retro cream / parchment canvas (matching the reference design)
    public let windowBackground = Color(red: 0.98, green: 0.96, blue: 0.93)
    // Pure crisp white card surface
    public let panelBackground = Color(red: 1.00, green: 1.00, blue: 1.00)
    // Subtle warm tinted secondary card surface
    public let panelBackgroundSecondary = Color(red: 0.95, green: 0.92, blue: 0.88)
    // Deep solid charcoal/black text
    public let textPrimary = Color(red: 0.08, green: 0.08, blue: 0.10)
    // Muted dark neutral secondary text
    public let textSecondary = Color(red: 0.40, green: 0.40, blue: 0.45)
    // Bold solid black outline
    public let borderPrimary = Color(red: 0.08, green: 0.08, blue: 0.10)

    // Neo-Brutalist Vibrant Pop Accents
    public let safeStatus = Color(red: 0.22, green: 0.78, blue: 0.52)       // Mint green (#38C784)
    public let lowRiskStatus = Color(red: 0.25, green: 0.52, blue: 0.96)    // Tech cobalt (#4084F5)
    public let mediumRiskStatus = Color(red: 1.00, green: 0.72, blue: 0.18) // Electric amber (#FFB82E)
    public let highRiskStatus = Color(red: 1.00, green: 0.40, blue: 0.42)   // Retro coral / salmon (#FF666B)
    public let protectedStatus = Color(red: 0.65, green: 0.40, blue: 0.95) // Lavender purple (#A666F3)
    public let cornerRadius: CGFloat = 12.0

    public init() {}
}
