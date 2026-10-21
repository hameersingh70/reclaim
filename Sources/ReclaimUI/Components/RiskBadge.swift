// RiskBadge.swift
// ReclaimUI/Components
//
// Accessible risk badge showing icon + label + color per PRD §53.

import SwiftUI
import Reclaim

public struct RiskBadge: View {
    public let risk: StorageRiskLevel
    public let theme: any Theme

    public init(risk: StorageRiskLevel, theme: any Theme) {
        self.risk = risk
        self.theme = theme
    }

    private var statusColor: Color {
        switch risk {
        case .safe: return theme.safeStatus
        case .low: return theme.lowRiskStatus
        case .medium: return theme.mediumRiskStatus
        case .high: return theme.highRiskStatus
        case .protected: return theme.protectedStatus
        case .unknown: return theme.textSecondary
        }
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text(risk.accessibilityIcon)
                .font(.system(size: 10, weight: .bold))
            Text(risk.displayLabel.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(statusColor)
        .foregroundColor(.black)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.black, lineWidth: 1.5)
        )
    }
}
