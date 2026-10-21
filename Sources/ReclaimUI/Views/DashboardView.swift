// DashboardView.swift
// ReclaimUI/Views
//
// Main storage overview dashboard displaying disk usage and reclaimable space per PRD §14.

import SwiftUI
import Reclaim

public struct DashboardView: View {
    @ObservedObject public var appState: AppState
    public let theme: any Theme

    public init(appState: AppState, theme: any Theme) {
        self.appState = appState
        self.theme = theme
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header stats (Neo-Brutalist Cards)
            HStack(spacing: 16) {
                StatCard(
                    title: "TOTAL INDEXED BYTES",
                    value: ByteCountFormatter.string(fromByteCount: appState.summary.totalAllocatedBytes, countStyle: .file),
                    badgeColor: Color(red: 0.35, green: 0.75, blue: 1.0)
                )
                StatCard(
                    title: "RECLAIMABLE SPACE",
                    value: appState.summary.formattedReclaimable,
                    badgeColor: Color(red: 1.00, green: 0.72, blue: 0.18),
                    highlight: true
                )
            }

            Text("STORAGE BY ECOSYSTEM MODULE")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(.black)
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(StorageCategory.allCases, id: \.self) { category in
                        let bytes = appState.summary.byCategory[category, default: 0]
                        if bytes > 0 {
                            HStack {
                                Text(category.displayName)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                                    .foregroundColor(.black)
                                    .cornerRadius(5)
                                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
                            .shadow(color: .black, radius: 0, x: 2, y: 2)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(theme.windowBackground)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    var badgeColor: Color = Color.white
    var highlight: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor)
                .foregroundColor(.black)
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1.2))

            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundColor(.black)
        }
        .padding(14)
        .frame(minWidth: 160, alignment: .leading)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 2))
        .shadow(color: .black, radius: 0, x: 3, y: 3)
    }
}
