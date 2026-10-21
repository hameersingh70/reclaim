// Theme.swift
// ReclaimUI/DesignSystem
//
// Semantic design tokens for Reclaim themes per PRD §39.

import SwiftUI

public protocol Theme: Sendable {
    var name: String { get }
    var windowBackground: Color { get }
    var panelBackground: Color { get }
    var panelBackgroundSecondary: Color { get }
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var borderPrimary: Color { get }
    var safeStatus: Color { get }
    var lowRiskStatus: Color { get }
    var mediumRiskStatus: Color { get }
    var highRiskStatus: Color { get }
    var protectedStatus: Color { get }
    var cornerRadius: CGFloat { get }
}

extension Theme {
    public var isCppTheme: Bool {
        false
    }

    public var fontDesign: Font.Design {
        .rounded
    }

    public var surface: Color { panelBackground }
    public var surfaceElevated: Color { panelBackgroundSecondary }
    public var background: Color { windowBackground }
    public var primaryText: Color { textPrimary }
    public var secondaryText: Color { textSecondary }
    public var border: Color { borderPrimary }
    public var accent: Color { Color(red: 0.35, green: 0.75, blue: 1.0) }
}

