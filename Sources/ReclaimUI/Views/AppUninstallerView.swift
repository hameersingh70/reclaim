// AppUninstallerView.swift
// ReclaimUI/Views
//
// Industry-leading Application Uninstaller and Leftover Cleaner (CleanMyMac & Pearcleaner style).
// Features:
// - Discovers all installed apps + their real sizes
// - Detects and aggregates hidden leftovers in ~/Library/Application Support, Caches, Preferences, Containers
// - Identifies ORPHANED leftovers left behind by previously deleted apps
// - 1-Click safe Trash-First uninstallation

import SwiftUI
import AppKit
import Reclaim

public struct AppUninstallerView: View {
    @ObservedObject public var appState: AppState
    public let theme: any Theme

    @State private var installedApps: [AppItem] = []
    @State private var orphanApps: [AppItem] = []
    @State private var isLoading: Bool = true
    @State private var isScanningOrphans: Bool = false
    @State private var includeSystemApps: Bool = false
    @State private var selectedTab: UninstallerTab = .installed
    @State private var selectedAppForDetail: AppItem? = nil
    @State private var searchQuery: String = ""
    @State private var actionMessage: String? = nil

    private let scanner = AppUninstallerScanner()

    public enum UninstallerTab: String, CaseIterable, Identifiable {
        case installed = "Installed Apps"
        case orphans = "Orphaned Leftovers"
        public var id: String { rawValue }
    }

    public init(appState: AppState, theme: any Theme) {
        self.appState = appState
        self.theme = theme
    }

    private var filteredInstalledApps: [AppItem] {
        if searchQuery.isEmpty { return installedApps }
        return installedApps.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) || $0.bundleIdentifier.localizedCaseInsensitiveContains(searchQuery) }
    }

    private var filteredOrphanApps: [AppItem] {
        if searchQuery.isEmpty { return orphanApps }
        return orphanApps.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    public var body: some View {
        VStack(spacing: 16) {
            headerCard

            tabToolbar

            if isLoading {
                loadingView
            } else {
                if selectedTab == .installed {
                    installedAppsList
                } else {
                    orphansList
                }
            }
        }
        .background(theme.windowBackground)
        .onAppear {
            loadApps()
        }
        .sheet(item: $selectedAppForDetail) { app in
            AppDetailSheet(
                app: app,
                theme: theme,
                onUninstall: { deleteLeftovers in
                    selectedAppForDetail = nil
                    performUninstall(app: app, deleteLeftovers: deleteLeftovers)
                },
                onRevealPath: { path in
                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                }
            )
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "app.badge.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 44, height: 44)
                .background(Color(red: 1.00, green: 0.40, blue: 0.42)) // Coral
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 2))
                .shadow(color: .black, radius: 0, x: 2, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text("Application Uninstaller")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                Text("Cleanly remove applications and scrub hidden leftover files and containers.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.65))
            }

            Spacer()

            if let msg = actionMessage {
                Text(msg)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.1, green: 0.6, blue: 0.2))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.2))
            }

            Button(action: { loadApps() }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                    Text("REFRESH")
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
            .disabled(isLoading)
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
        .shadow(color: .black, radius: 0, x: 3, y: 3)
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Tab Toolbar

    private var tabToolbar: some View {
        HStack(spacing: 12) {
            // Segmented buttons
            HStack(spacing: 6) {
                Button(action: { selectedTab = .installed }) {
                    Text("Installed Apps (\(installedApps.count))")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedTab == .installed ? Color(red: 1.00, green: 0.72, blue: 0.18) : Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.2))
                }
                .buttonStyle(.plain)

                Button(action: { selectedTab = .orphans }) {
                    HStack(spacing: 5) {
                        Text("Orphaned Leftovers")
                        if isScanningOrphans {
                            ProgressView().controlSize(.mini)
                        } else {
                            Text("(\(orphanApps.count))")
                            if !orphanApps.isEmpty {
                                Circle().fill(Color.red).frame(width: 6, height: 6)
                            }
                        }
                    }
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedTab == .orphans ? Color(red: 1.00, green: 0.72, blue: 0.18) : Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.2))
                }
                .buttonStyle(.plain)
            }

            // Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.black.opacity(0.6))
                TextField("Search apps or leftovers...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .rounded))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.2))

            // System Apps Toggle
            Button(action: {
                includeSystemApps.toggle()
                loadApps()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: includeSystemApps ? "checkmark.square.fill" : "square")
                        .font(.system(size: 11, weight: .bold))
                    Text("System Apps")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(includeSystemApps ? Color(red: 0.90, green: 0.92, blue: 1.0) : Color.white)
                .foregroundColor(.black)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.2))
            }
            .buttonStyle(.plain)
            .help("Toggle scanning of /System/Applications")

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView().controlSize(.large)
            Text("Inspecting applications and mapping Library leftovers...")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.black)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Installed Apps List

    private var installedAppsList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(filteredInstalledApps) { app in
                    HStack(spacing: 12) {
                        // Native App Icon
                        AppIconThumbnail(bundleURL: app.bundleURL, isOrphan: false, size: 34)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(app.name)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)

                                if app.isRunning {
                                    Text("RUNNING")
                                        .font(.system(size: 8, weight: .black, design: .monospaced))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color(red: 0.90, green: 0.20, blue: 0.20))
                                        .foregroundColor(.white)
                                        .cornerRadius(3)
                                }

                                if !app.leftovers.isEmpty {
                                    Text("+\(app.leftovers.count) leftovers (\(app.formattedLeftoversSize))")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                                        .foregroundColor(.black)
                                        .cornerRadius(3)
                                }
                            }

                            Text(app.bundleIdentifier.isEmpty ? app.bundleURL?.path ?? "" : app.bundleIdentifier)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color.black.opacity(0.55))
                                .lineLimit(1)
                        }

                        Spacer()

                        // Total Size Badge
                        Text(app.formattedTotalSize)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(minWidth: 70, alignment: .trailing)

                        // Inspect / Details Button
                        Button {
                            selectedAppForDetail = app
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 26, height: 26)
                                .background(Color.white)
                                .cornerRadius(5)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                                .shadow(color: .black, radius: 0, x: 1, y: 1)
                        }
                        .buttonStyle(.plain)
                        .help("Inspect application footprint and leftovers")

                        // Uninstall Button
                        Button {
                            selectedAppForDetail = app
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 10))
                                Text("UNINSTALL")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(red: 1.00, green: 0.40, blue: 0.42))
                            .foregroundColor(.black)
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                            .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
                    .shadow(color: .black, radius: 0, x: 2, y: 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Orphans List

    private var orphansList: some View {
        ScrollView {
            VStack(spacing: 8) {
                if filteredOrphanApps.isEmpty {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 40)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color(red: 0.22, green: 0.78, blue: 0.52))
                        Text("No Orphaned Leftovers Found")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                        Text("All Library data corresponds to currently installed applications.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Color.black.opacity(0.65))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    ForEach(filteredOrphanApps) { orphan in
                        HStack(spacing: 12) {
                            // Orphan Leftover Icon
                            AppIconThumbnail(bundleURL: nil, isOrphan: true, size: 34)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(orphan.name)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(.black)

                                    Text("DELETED APP LEFTOVER")
                                        .font(.system(size: 8, weight: .black, design: .monospaced))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.orange)
                                        .foregroundColor(.black)
                                        .cornerRadius(3)
                                }

                                Text("\(orphan.leftovers.count) leftover items scattered in ~/Library")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Color.black.opacity(0.55))
                            }

                            Spacer()

                            Text(orphan.formattedTotalSize)
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundColor(.black)

                            Button {
                                selectedAppForDetail = orphan
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 26, height: 26)
                                    .background(Color.white)
                                    .cornerRadius(5)
                                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                                    .shadow(color: .black, radius: 0, x: 1, y: 1)
                            }
                            .buttonStyle(.plain)

                            Button {
                                performUninstall(app: orphan, deleteLeftovers: true)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 10))
                                    Text("PURGE")
                                        .font(.system(size: 10, weight: .black, design: .rounded))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(red: 1.00, green: 0.40, blue: 0.42))
                                .foregroundColor(.black)
                                .cornerRadius(5)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                                .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
                        .shadow(color: .black, radius: 0, x: 2, y: 2)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Actions

    private func loadApps() {
        isLoading = true
        isScanningOrphans = true
        let includeSys = self.includeSystemApps
        Task {
            let apps = scanner.scanInstalledApps(includeSystemApps: includeSys)
            await MainActor.run {
                self.installedApps = apps
                self.isLoading = false
            }
            let orphans = scanner.scanOrphanLeftovers(knownApps: apps)
            await MainActor.run {
                self.orphanApps = orphans
                self.isScanningOrphans = false
            }
        }
    }

    private func performUninstall(app: AppItem, deleteLeftovers: Bool) {
        do {
            let reclaimed = try scanner.uninstall(app: app, deleteLeftovers: deleteLeftovers)
            let recStr = ByteCountFormatter.string(fromByteCount: reclaimed, countStyle: .file)
            actionMessage = "✓ Uninstalled \(app.name) (\(recStr) moved to Trash)"
            appState.appendTerminalLog("[uninstaller] \(app.name) uninstalled: \(recStr) moved to Trash.", level: .success)
            appState.notifyCleanupPerformed()
            loadApps()
        } catch {
            actionMessage = "Error: \(error.localizedDescription)"
            appState.appendTerminalLog("[uninstaller:err] Failed to uninstall \(app.name): \(error.localizedDescription)", level: .error)
        }
    }
}

// MARK: - App Detail Sheet

private struct AppDetailSheet: View {
    let app: AppItem
    let theme: any Theme
    let onUninstall: (Bool) -> Void
    let onRevealPath: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                AppIconThumbnail(bundleURL: app.bundleURL, isOrphan: app.isOrphan, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                    Text("Total Footprint: \(app.formattedTotalSize)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.black.opacity(0.65))
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 26, height: 26)
                        .background(Color.white)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                        .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.white)
            .overlay(Rectangle().frame(height: 1.5).foregroundColor(.black), alignment: .bottom)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Main App Binary
                    if let bundle = app.bundleURL {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("APPLICATION BUNDLE")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundColor(.black)

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bundle.lastPathComponent)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.black)
                                    Text(bundle.path)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(Color.black.opacity(0.6))
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(app.formattedAppSize)
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundColor(.black)

                                Button("Reveal") { onRevealPath(bundle.path) }
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .buttonStyle(.plain)
                                    .foregroundColor(.blue)
                            }
                            .padding(10)
                            .background(Color.white)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.2))
                        }
                    }

                    // Leftover Files
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ASSOCIATED DATA & LEFTOVERS (\(app.leftovers.count) ITEMS — \(app.formattedLeftoversSize))")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundColor(.black)

                        if app.leftovers.isEmpty {
                            Text("No additional Library data or preferences found.")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(Color.black.opacity(0.6))
                                .padding(10)
                        } else {
                            ForEach(app.leftovers) { leftover in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(leftover.category.rawValue)
                                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                                                .foregroundColor(.black)
                                                .cornerRadius(3)

                                            Text(URL(fileURLWithPath: leftover.path).lastPathComponent)
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundColor(.black)
                                                .lineLimit(1)
                                        }

                                        Text(leftover.path)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(Color.black.opacity(0.55))
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Text(leftover.formattedSize)
                                        .font(.system(size: 11, weight: .black, design: .monospaced))
                                        .foregroundColor(.black)

                                    Button("Reveal") { onRevealPath(leftover.path) }
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .buttonStyle(.plain)
                                        .foregroundColor(.blue)
                                }
                                .padding(8)
                                .background(Color.white)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.2), lineWidth: 1))
                            }
                        }
                    }
                }
                .padding(16)
            }

            // Footer Actions
            HStack(spacing: 12) {
                Spacer()

                Button("Cancel") { dismiss() }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.2))
                    .buttonStyle(.plain)

                Button {
                    dismiss()
                    onUninstall(true)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 10))
                        Text(app.isOrphan ? "PURGE ALL LEFTOVERS" : "UNINSTALL APP & LEFTOVERS")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 1.00, green: 0.40, blue: 0.42))
                    .foregroundColor(.black)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                    .shadow(color: .black, radius: 0, x: 2, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color.white)
            .overlay(Rectangle().frame(height: 1.5).foregroundColor(.black), alignment: .top)
        }
        .frame(minWidth: 550, minHeight: 480)
        .background(Color(red: 0.98, green: 0.96, blue: 0.93))
    }
}

// MARK: - App Icon Thumbnail

public struct AppIconThumbnail: View {
    public let bundleURL: URL?
    public let isOrphan: Bool
    public let size: CGFloat

    public init(bundleURL: URL?, isOrphan: Bool = false, size: CGFloat = 34) {
        self.bundleURL = bundleURL
        self.isOrphan = isOrphan
        self.size = size
    }

    private var appIcon: NSImage? {
        guard let bundleURL = bundleURL else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        icon.size = NSSize(width: size * 2, height: size * 2)
        return icon
    }

    public var body: some View {
        if let icon = appIcon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .cornerRadius(size * 0.22)
                .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(isOrphan ? Color(red: 1.00, green: 0.72, blue: 0.18) : Color(red: 0.35, green: 0.75, blue: 1.0))
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.22)
                            .stroke(Color.black, lineWidth: 1.2)
                    )
                Image(systemName: isOrphan ? "archivebox.fill" : "app.fill")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundColor(.black)
            }
            .frame(width: size, height: size)
        }
    }
}
