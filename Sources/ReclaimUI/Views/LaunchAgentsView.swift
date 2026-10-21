// LaunchAgentsView.swift
// ReclaimUI/Views
//
// Native SwiftUI view for managing background LaunchAgents & Daemons.
// Detects developer background services (PostgreSQL, Redis, Docker, Ollama)
// and identifies stale orphan plists whose binaries have been deleted.

import SwiftUI
import AppKit
import Reclaim

public struct LaunchAgentsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var themeManager: ThemeManager

    @State private var items: [LaunchAgentItem] = []
    @State private var selectedCategory: LaunchAgentCategory? = nil
    @State private var searchText: String = ""
    @State private var statusMessage: String? = nil
    private let manager = LaunchAgentsManager()

    public init(appState: AppState, themeManager: ThemeManager) {
        self.appState = appState
        self.themeManager = themeManager
    }

    private var theme: any Theme { themeManager.currentTheme }

    private var filteredItems: [LaunchAgentItem] {
        items.filter { item in
            let matchesCategory = selectedCategory == nil || item.category == selectedCategory
            let matchesSearch = searchText.isEmpty ||
                item.label.localizedCaseInsensitiveContains(searchText) ||
                (item.executablePath?.localizedCaseInsensitiveContains(searchText) ?? false)
            return matchesCategory && matchesSearch
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "cpu")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(theme.accent)
                        Text("Background Daemons & LaunchAgents")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(theme.primaryText)
                    }
                    Text("Audit background services running on boot. Unload resource-heavy daemons or trash orphaned plists.")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()

                Button(action: refreshItems) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(theme.surfaceElevated)
                    .foregroundColor(theme.primaryText)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(theme.surface)

            Divider().background(theme.border)

            // Search & Filter Bar
            HStack(spacing: 12) {
                // Search Field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(theme.secondaryText)
                    TextField("Search daemons or binaries...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(theme.primaryText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.surface)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.border, lineWidth: 1))
                .frame(maxWidth: 260)

                // Category Filter Pills
                FilterPill(title: "All (\(items.count))", isSelected: selectedCategory == nil, theme: theme) {
                    selectedCategory = nil
                }
                ForEach(LaunchAgentCategory.allCases, id: \.self) { cat in
                    let count = items.filter { $0.category == cat }.count
                    if count > 0 {
                        FilterPill(title: "\(cat.rawValue) (\(count))", isSelected: selectedCategory == cat, theme: theme) {
                            selectedCategory = cat
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(theme.surfaceElevated.opacity(0.5))

            Divider().background(theme.border)

            // Status Banner
            if let msg = statusMessage {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(theme.accent)
                    Text(msg)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.primaryText)
                    Spacer()
                    Button("Dismiss") { statusMessage = nil }
                        .font(.system(size: 11))
                        .foregroundColor(theme.secondaryText)
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(theme.accent.opacity(0.1))
                Divider().background(theme.border)
            }

            // Daemons List
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 40))
                        .foregroundColor(theme.accent)
                    Text("No matching background daemons found.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredItems) { item in
                            DaemonRow(
                                item: item,
                                theme: theme,
                                onToggle: { enable in toggleDaemon(item, enable: enable) },
                                onTrash: { trashDaemon(item) },
                                onReveal: { revealInFinder(item) }
                            )
                        }
                    }
                    .padding(24)
                }
            }
        }
        .background(theme.background)
        .onAppear {
            refreshItems()
        }
    }

    private func refreshItems() {
        items = manager.scan()
    }

    private func toggleDaemon(_ item: LaunchAgentItem, enable: Bool) {
        let res = manager.setEnabled(item: item, enable: enable)
        statusMessage = res.message
        appState.appendTerminalLog("[daemon:\(enable ? "start" : "stop")] \(item.label)", level: res.success ? .success : .error)
        refreshItems()
    }

    private func trashDaemon(_ item: LaunchAgentItem) {
        let res = manager.trash(item: item)
        statusMessage = res.message
        appState.appendTerminalLog("[daemon:trash] \(item.label) moved to Trash", level: res.success ? .warning : .error)
        refreshItems()
    }

    private func revealInFinder(_ item: LaunchAgentItem) {
        NSWorkspace.shared.selectFile(item.plistPath, inFileViewerRootedAtPath: "")
    }
}

// MARK: - Subcomponents

private struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let theme: any Theme
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? theme.accent.opacity(0.2) : theme.surfaceElevated)
                .foregroundColor(isSelected ? theme.accent : theme.secondaryText)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? theme.accent : theme.border, lineWidth: 1)
                )
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

private struct DaemonRow: View {
    let item: LaunchAgentItem
    let theme: any Theme
    let onToggle: (Bool) -> Void
    let onTrash: () -> Void
    let onReveal: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Status Icon Indicator
            Circle()
                .fill(item.isRunning ? Color.green : (item.isOrphan ? Color.red : Color.gray.opacity(0.5)))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.primaryText)

                    // Category Badge
                    CategoryBadge(category: item.category)

                    if let pid = item.pid {
                        Text("PID: \(pid)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(theme.secondaryText)
                    }

                    if item.isOrphan {
                        Text("ORPHAN")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(3)
                    }
                }

                if let exec = item.executablePath {
                    Text(exec)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(theme.secondaryText.opacity(0.8))
                        .lineLimit(1)
                }

                Text(item.plistPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(theme.secondaryText.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                // Reveal in Finder
                Button(action: onReveal) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                        .padding(6)
                        .background(theme.surfaceElevated)
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Reveal plist in Finder")

                // Start / Stop Toggle
                Button(action: { onToggle(!item.isRunning) }) {
                    Text(item.isRunning ? "Unload" : "Load")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(item.isRunning ? .orange : theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.surfaceElevated)
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)

                // Trash Plist Button
                Button(action: onTrash) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Move plist to ~/.Trash")
            }
        }
        .padding(14)
        .background(theme.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(item.isOrphan ? Color.red.opacity(0.3) : theme.border, lineWidth: 1)
        )
    }
}

private struct CategoryBadge: View {
    let category: LaunchAgentCategory

    var body: some View {
        let (color, text): (Color, String) = {
            switch category {
            case .developer: return (.blue, "Developer")
            case .application: return (.purple, "App")
            case .orphan: return (.red, "Missing Binary")
            case .system: return (.gray, "System")
            }
        }()

        Text(text)
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}
