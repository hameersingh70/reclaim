// ModernTheme.swift
// ReclaimUI/DesignSystem
//
// Modern native macOS appearance: subtle rounded corners, increased whitespace per PRD §43.

import SwiftUI

public struct ModernTheme: Theme {
    public let name = "Modern"
    public let windowBackground = Color(nsColor: .windowBackgroundColor)
    public let panelBackground = Color(nsColor: .controlBackgroundColor)
    public let panelBackgroundSecondary = Color.secondary.opacity(0.1)
    public let textPrimary = Color.primary
    public let textSecondary = Color.secondary
    public let borderPrimary = Color(nsColor: .separatorColor)
    public let safeStatus = Color.green
    public let lowRiskStatus = Color.blue
    public let mediumRiskStatus = Color.orange
    public let highRiskStatus = Color.red
    public let protectedStatus = Color.purple
    public let cornerRadius: CGFloat = 8.0

    public init() {}
}
