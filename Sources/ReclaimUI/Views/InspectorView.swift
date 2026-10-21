// InspectorView.swift
// ReclaimUI/Views
//
// Detailed inspector panel answering all 10 core product questions per PRD §3 and §48.

import SwiftUI
import AppKit
import Reclaim

public struct InspectorView: View {
    public let item: StorageItem?
    public let theme: any Theme
    public var onDeleteItem: (() -> Void)? = nil
    public var onRevealInFinder: (() -> Void)? = nil

    public init(
        item: StorageItem?,
        theme: any Theme,
        onDeleteItem: (() -> Void)? = nil,
        onRevealInFinder: (() -> Void)? = nil
    ) {
        self.item = item
        self.theme = theme
        self.onDeleteItem = onDeleteItem
        self.onRevealInFinder = onRevealInFinder
    }

    public var body: some View {
        ScrollView {
            if let item = item {
                VStack(alignment: .leading, spacing: 14) {
                    // Header (Neo-Brutalist Card)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(URL(fileURLWithPath: item.path).lastPathComponent)
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundColor(.black)
                                    .lineLimit(2)

                                Text(item.path)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Color.black.opacity(0.6))
                                    .lineLimit(2)
                            }
                            Spacer()
                            RiskBadge(risk: item.risk, theme: theme)
                        }

                        // Action Buttons Bar
                        HStack(spacing: 8) {
                            Button(action: {
                                if let onReveal = onRevealInFinder {
                                    onReveal()
                                } else {
                                    NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("REVEAL IN FINDER")
                                        .font(.system(size: 10, weight: .black, design: .rounded))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.2))
                                .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                            }
                            .buttonStyle(.plain)

                            if item.isEligibleForPlan {
                                Button(action: {
                                    onDeleteItem?()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 10, weight: .bold))
                                        Text("MOVE TO TRASH")
                                            .font(.system(size: 10, weight: .black, design: .rounded))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(red: 1.00, green: 0.40, blue: 0.42))
                                    .foregroundColor(.black)
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.2))
                                    .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 1.5))
                    .shadow(color: .black, radius: 0, x: 2, y: 2)

                    // Metrics grid (Neo-Brutalist Stat Pills)
                    HStack(spacing: 8) {
                        MetricBlock(label: "Allocated", value: item.formattedAllocatedSize, color: Color(red: 1.00, green: 0.72, blue: 0.18))
                        MetricBlock(label: "Logical", value: ByteCountFormatter.string(fromByteCount: item.logicalSize, countStyle: .file), color: Color(red: 0.35, green: 0.75, blue: 1.0))
                        MetricBlock(label: "Reclaimable", value: item.formattedReclaimableSize, color: Color(red: 0.22, green: 0.78, blue: 0.52))
                    }

                    // 10 Core Product Answers (PRD §3)
                    VStack(spacing: 8) {
                        QuestionAnswer(question: "What is this?", answer: item.whatIsThis ?? "Detected storage item")
                        QuestionAnswer(question: "Why does it exist?", answer: item.whyItExists ?? "Created by developer tools or OS")
                        QuestionAnswer(question: "What happens if removed?", answer: item.removalConsequence ?? "May require manual restoration or re-download")
                        QuestionAnswer(question: "How is it recovered?", answer: item.recoveryInstruction ?? item.recoverability.displayLabel)
                        QuestionAnswer(question: "Tool / Ecosystem", answer: item.category.displayName)
                    }
                }
                .padding(14)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 32))
                        .foregroundColor(Color.black.opacity(0.4))
                    Text("Select a storage item to inspect domain intelligence.")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.black.opacity(0.6))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(20)
            }
        }
        .background(theme.windowBackground)
    }
}

private struct MetricBlock: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundColor(Color.black.opacity(0.7))
            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(.black)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.2))
        .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
    }
}

private struct QuestionAnswer: View {
    let question: String
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(question)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.black)
            Text(answer)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color.black.opacity(0.75))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.2))
        .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
    }
}
