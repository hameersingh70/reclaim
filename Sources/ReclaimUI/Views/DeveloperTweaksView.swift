// DeveloperTweaksView.swift
// ReclaimUI/Views
//
// Native SwiftUI view for Developer macOS Tweaks & Hidden Defaults.
// Allows developers to inspect and toggle essential macOS flags:
// hidden dotfiles, file extensions, full POSIX paths, .DS_Store suppression,
// Dock speed acceleration, and Xcode build timers.

import SwiftUI
import Reclaim

public struct DeveloperTweaksView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var themeManager: ThemeManager

    @State private var tweaks: [DeveloperTweakItem] = []
    @State private var selectedCategory: TweakCategory? = nil
    @State private var statusMessage: String? = nil
    @State private var isPruningSimulators = false
    private let engine = DeveloperTweaksEngine()

    public init(appState: AppState, themeManager: ThemeManager) {
        self.appState = appState
        self.themeManager = themeManager
    }

    private var theme: any Theme { themeManager.currentTheme }

    private var filteredTweaks: [DeveloperTweakItem] {
        if let cat = selectedCategory {
            return tweaks.filter { $0.category == cat }
        }
        return tweaks
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(theme.accent)
                        Text("Developer macOS Tweaks")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(theme.primaryText)
                    }
                    Text("Configure hidden macOS defaults, Finder views, Dock animations, and toolchain optimizations.")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()

                Button(action: refreshTweaks) {
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

            // Category Filter Bar
            HStack(spacing: 8) {
                FilterPill(title: "All Tweaks", isSelected: selectedCategory == nil, theme: theme) {
                    selectedCategory = nil
                }
                ForEach(TweakCategory.allCases, id: \.self) { cat in
                    FilterPill(title: cat.rawValue, isSelected: selectedCategory == cat, theme: theme) {
                        selectedCategory = cat
                    }
                }
                Spacer()

                // Simulator Pruning Quick Action
                Button(action: runPruneSimulators) {
                    HStack(spacing: 6) {
                        if isPruningSimulators {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "trash")
                        }
                        Text("Prune Stale Simulators")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isPruningSimulators)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(theme.surfaceElevated.opacity(0.5))

            Divider().background(theme.border)

            // Status Banner if present
            if let msg = statusMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(msg)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.primaryText)
                    Spacer()
                    Button("Dismiss") {
                        statusMessage = nil
                    }
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondaryText)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                Divider().background(theme.border)
            }

            // Tweaks List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredTweaks) { tweak in
                        TweakCard(tweak: tweak, theme: theme) { enabled in
                            toggleTweak(tweak, enabled: enabled)
                        }
                    }
                }
                .padding(24)
            }
        }
        .background(theme.background)
        .onAppear {
            refreshTweaks()
        }
    }

    private func refreshTweaks() {
        tweaks = engine.loadTweaks()
    }

    private func toggleTweak(_ tweak: DeveloperTweakItem, enabled: Bool) {
        let success = engine.setTweak(tweak, enabled: enabled)
        if success {
            refreshTweaks()
            let actionStr = enabled ? "enabled" : "disabled"
            statusMessage = "\(tweak.title) \(actionStr)."
            appState.appendTerminalLog("[tweak:\(actionStr)] \(tweak.title) (\(tweak.domain) \(tweak.key))", level: .success)
        }
    }

    private func runPruneSimulators() {
        isPruningSimulators = true
        appState.appendTerminalLog("[simctl:prune] Deleting unavailable Xcode simulators and device runtimes...", level: .warning)
        DispatchQueue.global(qos: .userInitiated).async {
            let res = self.engine.pruneUnavailableSimulators()
            DispatchQueue.main.async {
                self.isPruningSimulators = false
                self.statusMessage = res.message
                self.appState.appendTerminalLog("[simctl:result] \(res.message)", level: res.success ? .success : .info)
            }
        }
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
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 12)
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

private struct TweakCard: View {
    let tweak: DeveloperTweakItem
    let theme: any Theme
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(tweak.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(theme.primaryText)

                    Text(tweak.category.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.surfaceElevated)
                        .foregroundColor(theme.secondaryText)
                        .cornerRadius(4)

                    if let restart = tweak.restartService {
                        Text("Restarts \(restart)")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                Text(tweak.description)
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)

                Text("defaults write \(tweak.domain) \(tweak.key)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(theme.secondaryText.opacity(0.7))
                    .padding(.top, 2)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { tweak.isEnabled },
                set: { onToggle($0) }
            ))
            .toggleStyle(SwitchToggleStyle(tint: theme.accent))
            .labelsHidden()
        }
        .padding(16)
        .background(theme.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tweak.isEnabled ? theme.accent.opacity(0.4) : theme.border, lineWidth: 1)
        )
    }
}
