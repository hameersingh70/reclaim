// DuplicateAssetsView.swift
// ReclaimUI/Views
//
// Native SwiftUI view for Duplicate AI Weights & Developer Assets.
// Identifies identical .gguf, .safetensors, .iso, and .dmg files across
// Ollama, HuggingFace, LM Studio, Downloads, and Developer folders using
// high-speed 2-tier sparse chunk hashing.

import SwiftUI
import AppKit
import Reclaim

public struct DuplicateAssetsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var themeManager: ThemeManager

    @State private var duplicateGroups: [DuplicateAssetGroup] = []
    @State private var isScanning = false
    @State private var scanStatus: String = ""
    @State private var selectedItemsToTrash: Set<String> = []
    private let detector = DuplicateAssetDetector()

    public init(appState: AppState, themeManager: ThemeManager) {
        self.appState = appState
        self.themeManager = themeManager
    }

    private var theme: any Theme { themeManager.currentTheme }

    private var totalSavings: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.potentialSavings }
    }

    private var formattedTotalSavings: String {
        ByteCountFormatter.string(fromByteCount: totalSavings, countStyle: .file)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.on.square.dashed")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(theme.accent)
                        Text("Duplicate AI Models & Large Assets")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(theme.primaryText)
                    }
                    Text("Sparse-hash duplicate detection for multi-gigabyte LLM weights, disk images, and packages.")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()

                if !duplicateGroups.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Reclaimable")
                            .font(.system(size: 11))
                            .foregroundColor(theme.secondaryText)
                        Text(formattedTotalSavings)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .padding(.trailing, 12)
                }

                Button(action: startScan) {
                    HStack(spacing: 6) {
                        if isScanning {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text(isScanning ? "Scanning..." : "Scan Duplicates")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(theme.accent)
                    .foregroundColor(.black)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isScanning)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(theme.surface)

            Divider().background(theme.border)

            if isScanning {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text(scanStatus.isEmpty ? "Scanning developer directories..." : scanStatus)
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                    Spacer()
                }
            } else if duplicateGroups.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 44))
                        .foregroundColor(.green)
                    Text("No Duplicate Models or Assets Detected")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(theme.primaryText)
                    Text("Click 'Scan Duplicates' to evaluate Ollama, HuggingFace, LM Studio, Downloads, and Projects.")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(duplicateGroups.enumerated()), id: \.element.id) { index, group in
                            DuplicateGroupCard(
                                groupIndex: index + 1,
                                group: group,
                                theme: theme,
                                onTrashItem: { item in trashSingleItem(item) },
                                onRevealItem: { item in revealInFinder(item) }
                            )
                        }
                    }
                    .padding(24)
                }
            }
        }
        .background(theme.background)
        .onAppear {
            if duplicateGroups.isEmpty && !isScanning {
                startScan()
            }
        }
    }

    private func startScan() {
        isScanning = true
        scanStatus = "Initiating sparse chunk hash scan..."
        appState.appendTerminalLog("[dup:scan] Starting 2-tier sparse chunk hash detection...", level: .info)

        Task {
            let results = await detector.scan { progress in
                Task { @MainActor in
                    self.scanStatus = progress
                }
            }
            await MainActor.run {
                self.duplicateGroups = results
                self.isScanning = false
                let savStr = ByteCountFormatter.string(fromByteCount: self.totalSavings, countStyle: .file)
                self.appState.appendTerminalLog("[dup:complete] Found \(results.count) duplicate groups. Potential reclaim: \(savStr).", level: .success)
            }
        }
    }

    private func trashSingleItem(_ item: DuplicateAssetItem) {
        let fileURL = URL(fileURLWithPath: item.path)
        do {
            try FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
            appState.appendTerminalLog("[dup:trash] Moved duplicate \(item.fileName) to Trash.", level: .success)
            // Remove item from groups
            duplicateGroups = duplicateGroups.compactMap { group in
                let updatedItems = group.items.filter { $0.id != item.id }
                if updatedItems.count > 1 {
                    return DuplicateAssetGroup(id: group.id, fileSize: group.fileSize, items: updatedItems)
                }
                return nil
            }
        } catch {
            appState.appendTerminalLog("[dup:err] Failed to trash: \(error.localizedDescription)", level: .error)
        }
    }

    private func revealInFinder(_ item: DuplicateAssetItem) {
        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
    }
}

// MARK: - Subcomponents

private struct DuplicateGroupCard: View {
    let groupIndex: Int
    let group: DuplicateAssetGroup
    let theme: any Theme
    let onTrashItem: (DuplicateAssetItem) -> Void
    let onRevealItem: (DuplicateAssetItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Group Header
            HStack {
                Text("Group #\(groupIndex)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.primaryText)

                Text("\(group.items.count) Identical Copies")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.surfaceElevated)
                    .foregroundColor(theme.secondaryText)
                    .cornerRadius(4)

                Spacer()

                Text("Potential Savings: \(group.formattedSavings)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.green)
            }

            Divider().background(theme.border)

            // Files in group
            ForEach(Array(group.items.enumerated()), id: \.element.id) { idx, item in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(item.fileName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.primaryText)

                            if idx == 0 {
                                Text("ORIGINAL (OLDEST)")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .cornerRadius(3)
                            } else {
                                Text("DUPLICATE")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundColor(.orange)
                                    .cornerRadius(3)
                            }
                        }

                        Text(item.path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(theme.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: { onRevealItem(item) }) {
                            Image(systemName: "folder")
                                .font(.system(size: 11))
                                .padding(5)
                                .background(theme.surfaceElevated)
                                .foregroundColor(theme.secondaryText)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")

                        if idx > 0 {
                            Button(action: { onTrashItem(item) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                    Text("Trash Copy")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.12))
                                .foregroundColor(.red)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(theme.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.border, lineWidth: 1)
        )
    }
}
