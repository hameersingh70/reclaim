// ClassicTheme.swift
// ReclaimUI/DesignSystem
//
// Traditional workstation appearance: cold neutral tones, sharp rectangular panels,
// minimal corner radius, dense information presentation per PRD §40.

import SwiftUI

public struct ClassicTheme: Theme {
    public let name = "Classic"
    public let windowBackground = Color(white: 0.92)
    public let panelBackground = Color(white: 0.98)
    public let panelBackgroundSecondary = Color(white: 0.88)
    public let textPrimary = Color.black
    public let textSecondary = Color(white: 0.35)
    public let borderPrimary = Color(white: 0.70)
    public let safeStatus = Color(red: 0.1, green: 0.6, blue: 0.2)
    public let lowRiskStatus = Color(red: 0.2, green: 0.5, blue: 0.8)
    public let mediumRiskStatus = Color(red: 0.85, green: 0.55, blue: 0.1)
    public let highRiskStatus = Color(red: 0.8, green: 0.2, blue: 0.2)
    public let protectedStatus = Color(white: 0.4)
    public let cornerRadius: CGFloat = 0.0

    public init() {}
}
