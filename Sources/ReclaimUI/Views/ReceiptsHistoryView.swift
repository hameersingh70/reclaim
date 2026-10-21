// ReceiptsHistoryView.swift
// ReclaimUI/Views
//
// History log of past cleanups, bytes recovered, and recovery audit trail per PRD §21.
// Connects directly to SQLite persistent receipts database across app restarts.

import SwiftUI
import AppKit
import Reclaim

public struct ReceiptsHistoryView: View {
    @ObservedObject public var appState: AppState
    public let theme: any Theme

    @State private var expandedReceiptID: UUID? = nil

    public init(appState: AppState, theme: any Theme) {
        self.appState = appState
        self.theme = theme
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header Bar (Neo-Brutalist Card)
            headerCard

            if appState.historicalReceipts.isEmpty && appState.lastReceipt == nil {
                emptyState
            } else {
                receiptsScrollView
            }
        }
        .background(theme.windowBackground)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 44, height: 44)
                .background(Color(red: 0.40, green: 0.88, blue: 0.60)) // Mint
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 2))
                .shadow(color: .black, radius: 0, x: 2, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text("Cleanup History & Receipts")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                Text("Persistent audit trail of all previous space recovery operations.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.65))
            }

            Spacer()

            // All-Time Reclaimed Badge
            VStack(alignment: .trailing, spacing: 2) {
                Text(appState.formattedAllTimeRecovered)
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                    .foregroundColor(.black)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))

                Text("All-Time Space Reclaimed")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.6))
            }

            Button {
                if let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first {
                    NSWorkspace.shared.open(trashURL)
                } else {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "\(NSHomeDirectory())/.Trash"))
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 11))
                    Text("Open Trash")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                .shadow(color: .black, radius: 0, x: 2, y: 2)
            }
            .buttonStyle(.plain)
            .help("Reveal macOS Trash directory")
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
        .shadow(color: .black, radius: 0, x: 3, y: 3)
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Receipts List

    private var receiptsList: [CleanupReceipt] {
        var list = appState.historicalReceipts
        if let last = appState.lastReceipt, !list.contains(where: { $0.id == last.id }) {
            list.insert(last, at: 0)
        }
        return list
    }

    private var receiptsScrollView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(receiptsList) { receipt in
                    let isExpanded = (expandedReceiptID == receipt.id) || (expandedReceiptID == nil && receipt.id == receiptsList.first?.id)

                    VStack(alignment: .leading, spacing: 0) {
                        // Session Header Row
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.22, green: 0.78, blue: 0.52)) // Mint
                                    .frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(Color.black, lineWidth: 1.5))

                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundColor(.black)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text("CLEANUP SESSION")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                                        .foregroundColor(.black)
                                        .cornerRadius(4)
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1))

                                    Text(receipt.timestamp.formatted(date: .abbreviated, time: .standard))
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.black.opacity(0.75))
                                }

                                Text("Recovered: \(receipt.formattedRecovered) (\(receipt.actions.count) items)")
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundColor(.black)
                            }

                            Spacer()

                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if expandedReceiptID == receipt.id {
                                        expandedReceiptID = UUID() // collapse
                                    } else {
                                        expandedReceiptID = receipt.id
                                    }
                                }
                            } label: {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 26, height: 26)
                                    .background(Color.white)
                                    .cornerRadius(5)
                                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                                    .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .background(Color(red: 0.98, green: 0.98, blue: 0.98))

                        if isExpanded {
                            Divider().background(Color.black.opacity(0.15))

                            VStack(spacing: 6) {
                                ForEach(receipt.actions, id: \.path) { action in
                                    HStack(spacing: 10) {
                                        Image(systemName: action.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                            .foregroundColor(action.success ? Color(red: 0.22, green: 0.78, blue: 0.52) : Color.orange)
                                            .font(.system(size: 12))

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(URL(fileURLWithPath: action.path).lastPathComponent)
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundColor(.black)
                                                .lineLimit(1)

                                            Text(action.path)
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundColor(Color.black.opacity(0.55))
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        Text(ByteCountFormatter.string(fromByteCount: action.reclaimedBytes, countStyle: .file))
                                            .font(.system(size: 11, weight: .black, design: .monospaced))
                                            .foregroundColor(.black)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.2), lineWidth: 1))
                                }
                            }
                            .padding(12)
                            .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 1.8))
                    .shadow(color: .black, radius: 0, x: 2.5, y: 2.5)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color(red: 0.35, green: 0.75, blue: 1.0))
                    .frame(width: 64, height: 64)
                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
                    .shadow(color: .black, radius: 0, x: 3, y: 3)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.black)
            }

            Text("No Cleanup Receipts Recorded")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.black)
            Text("Run a Smart Scan or module clean to generate verifiable audit receipts here.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color.black.opacity(0.65))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
        .shadow(color: .black, radius: 0, x: 3, y: 3)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}
