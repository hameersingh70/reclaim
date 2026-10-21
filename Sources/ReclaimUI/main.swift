// main.swift
// ReclaimUI
//
// Native macOS desktop application for Reclaim.
// Designed with a CleanMyMac / CCleaner paradigm: sidebar modules, Smart Scan hero view,
// interactive checklist selection, and 1-click safe cleaning to Trash.

import SwiftUI
import AppKit
import Reclaim

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let sentinel = LightweightSentinelMonitor.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        setupStatusBar()
        startSentinel()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Stay running in menu bar as lightweight background sentinel
    }

    private func startSentinel() {
        sentinel.onPressureChanged = { [weak self] report in
            Task { @MainActor in
                self?.updateStatusBar(report: report)
            }
        }
        sentinel.onSlownessDetected = { report, message in
            Task { @MainActor in
                NotificationCenter.default.post(name: NSNotification.Name("ReclaimSlownessAlert"), object: message)
            }
        }
        sentinel.onLowStorageDetected = { availableBytes, message in
            Task { @MainActor in
                NotificationCenter.default.post(name: NSNotification.Name("ReclaimLowStorageAlert"), object: message)
            }
        }
        sentinel.start()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        button.title = "⚡ Reclaim"
        button.toolTip = "Reclaim — macOS System & Developer Storage Optimizer"

        let menu = NSMenu()
        let titleItem = NSMenuItem(title: "Reclaim for macOS", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        // Storage metric
        let metrics = SystemStorageInspector().getVolumeMetrics()
        let freeStr = ByteCountFormatter.string(fromByteCount: metrics.available, countStyle: .file)
        let storageItem = NSMenuItem(title: "Free Storage: \(freeStr)", action: nil, keyEquivalent: "")
        storageItem.isEnabled = false
        menu.addItem(storageItem)

        menu.addItem(NSMenuItem.separator())

        let viewInsightsItem = NSMenuItem(title: "View Slowness Insights...", action: #selector(openInsightsAction), keyEquivalent: "i")
        viewInsightsItem.target = self
        menu.addItem(viewInsightsItem)

        let purgeRAMItem = NSMenuItem(title: "Purge Inactive RAM", action: #selector(purgeRAMAction), keyEquivalent: "p")
        purgeRAMItem.target = self
        menu.addItem(purgeRAMItem)

        let flushDNSItem = NSMenuItem(title: "Flush DNS Cache", action: #selector(flushDNSAction), keyEquivalent: "")
        flushDNSItem.target = self
        menu.addItem(flushDNSItem)

        let fdaItem = NSMenuItem(title: "Full Disk Access Settings...", action: #selector(openFullDiskAccessAction), keyEquivalent: "")
        fdaItem.target = self
        menu.addItem(fdaItem)

        menu.addItem(NSMenuItem.separator())

        let openAppItem = NSMenuItem(title: "Open Reclaim", action: #selector(openAppAction), keyEquivalent: "o")
        openAppItem.target = self
        menu.addItem(openAppItem)

        let quitItem = NSMenuItem(title: "Quit Reclaim", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    func updateStatusBar(report: PressureReport) {
        guard let button = statusItem?.button else { return }

        switch report.pressureLevel {
        case .normal:
            button.title = "⚡ Reclaim"
        case .warning:
            button.title = "⚡ Reclaim (\(Int(report.metrics.pressurePercentage))%)"
        case .critical:
            button.title = "⚡ Reclaim (SLOWNESS ⚠️)"
        }

        guard let menu = statusItem?.menu else { return }
        menu.removeAllItems()

        let titleItem = NSMenuItem(title: "Reclaim for macOS", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let metrics = SystemStorageInspector().getVolumeMetrics()
        let freeStr = ByteCountFormatter.string(fromByteCount: metrics.available, countStyle: .file)
        let storageItem = NSMenuItem(title: "Free Storage: \(freeStr)", action: nil, keyEquivalent: "")
        storageItem.isEnabled = false
        menu.addItem(storageItem)

        let memStr = "RAM: \(Int(report.metrics.pressurePercentage))% (Swap: \(report.metrics.formattedSwapUsed))"
        let memItem = NSMenuItem(title: memStr, action: nil, keyEquivalent: "")
        memItem.isEnabled = false
        menu.addItem(memItem)

        if let firstCause = report.rootCauses.first {
            let causeItem = NSMenuItem(title: "⚠️ \(firstCause.title)", action: #selector(openInsightsAction), keyEquivalent: "")
            causeItem.target = self
            menu.addItem(causeItem)
        }

        menu.addItem(NSMenuItem.separator())

        let viewInsightsItem = NSMenuItem(title: "View Slowness Insights...", action: #selector(openInsightsAction), keyEquivalent: "i")
        viewInsightsItem.target = self
        menu.addItem(viewInsightsItem)

        let purgeRAMItem = NSMenuItem(title: "Purge Inactive RAM", action: #selector(purgeRAMAction), keyEquivalent: "p")
        purgeRAMItem.target = self
        menu.addItem(purgeRAMItem)

        let flushDNSItem = NSMenuItem(title: "Flush DNS Cache", action: #selector(flushDNSAction), keyEquivalent: "")
        flushDNSItem.target = self
        menu.addItem(flushDNSItem)

        let fdaItem = NSMenuItem(title: "Full Disk Access Settings...", action: #selector(openFullDiskAccessAction), keyEquivalent: "")
        fdaItem.target = self
        menu.addItem(fdaItem)

        menu.addItem(NSMenuItem.separator())

        let openAppItem = NSMenuItem(title: "Open Reclaim", action: #selector(openAppAction), keyEquivalent: "o")
        openAppItem.target = self
        menu.addItem(openAppItem)

        let quitItem = NSMenuItem(title: "Quit Reclaim", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func openInsightsAction() {
        openAppAction()
        NotificationCenter.default.post(name: NSNotification.Name("ReclaimNavigateToInsights"), object: nil)
    }

    @objc private func purgeRAMAction() {
        Task {
            _ = await SystemMaintenanceEngine().execute(task: .purgeRAM)
        }
    }

    @objc private func flushDNSAction() {
        Task {
            _ = await SystemMaintenanceEngine().execute(task: .flushDNS)
        }
    }

    @objc private func openFullDiskAccessAction() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openAppAction() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }
}

// MARK: - Navigation Target

enum NavigationSection: Hashable {
    case smartScan
    case systemStorage
    // Developer Ecosystems
    case xcode
    case docker
    case node
    case gradle
    case homebrew
    case ruby
    case jvm
    case rust
    // AI / ML
    case llm
    case mlFrameworks
    case pythonEnv
    // System Utilities
    case uninstaller
    case maintenance
    case shredder
    case backups
    case largeFiles
    // Developer Tuning & Power Tools
    case tweaks
    case daemons
    case duplicates
    // Utilities
    case explorer
    case history
    case pressureInsights
}

// MARK: - Application Entry

struct ReclaimApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            MainShellView(appState: appState, themeManager: themeManager)
                .frame(minWidth: 1020, idealWidth: 1100, minHeight: 700, idealHeight: 800)
                .navigationTitle("")
        }
        .defaultSize(width: 1100, height: 800)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
    }
}

ReclaimApp.main()

// MARK: - Main Shell View

struct MainShellView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var themeManager: ThemeManager
    @State private var selectedSection: NavigationSection? = {
        if CommandLine.arguments.contains("--explorer") { return .explorer }
        if CommandLine.arguments.contains("--storage") { return .systemStorage }
        if CommandLine.arguments.contains("--uninstaller") { return .uninstaller }
        if CommandLine.arguments.contains("--maintenance") { return .maintenance }
        if CommandLine.arguments.contains("--shredder") { return .shredder }
        if CommandLine.arguments.contains("--pressure") { return .pressureInsights }
        if CommandLine.arguments.contains("--tweaks") { return .tweaks }
        if CommandLine.arguments.contains("--daemons") { return .daemons }
        if CommandLine.arguments.contains("--duplicates") { return .duplicates }
        return .smartScan
    }()
    @State private var activeScanTask: Task<Void, Never>? = nil

    private var isScanning: Bool {
        if case .scanning = appState.scanPhase { return true }
        return false
    }

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 230, ideal: 250, max: 290)
                .background(themeManager.currentTheme.windowBackground)
        } detail: {
            VStack(spacing: 0) {
                if let alert = appState.activeSlownessAlert {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.black)
                        Text("⚡ RECLAIM ALERT: \(alert)")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                        Spacer()
                        Button(action: {
                            selectedSection = .pressureInsights
                            appState.dismissSlownessAlert()
                        }) {
                            Text("VIEW INSIGHTS")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(red: 1.00, green: 0.84, blue: 0.00))
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            appState.dismissSlownessAlert()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.black)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 1.00, green: 0.42, blue: 0.42))
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 1.5))
                }

                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                CppTerminalView(
                    appState: appState,
                    theme: themeManager.currentTheme,
                    onStartScan: { category in
                        startTargetedDeveloperScan(category: category)
                    },
                    onExecuteClean: {
                        executeCleanSelected()
                    },
                    onForceRescan: {
                        forceRescan()
                    }
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 8) {
                    Text("RECLAIM")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.black)

                    Text("DEV PURGE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                        .foregroundColor(.black)
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1.5))
                }
            }

            ToolbarItem(placement: .automatic) {
                if isScanning {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Button(action: { cancelScan() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text("HALT SCAN")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(red: 1.00, green: 0.40, blue: 0.42))
                            .foregroundColor(.black)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                            .shadow(color: .black, radius: 0, x: 2, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    HStack(spacing: 8) {
                        Button(action: { forceRescan() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10, weight: .bold))
                                Text("RESCAN FRESH")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                            .shadow(color: .black, radius: 0, x: 2, y: 2)
                        }
                        .buttonStyle(.plain)
                        .help("Purge directory cache and run fresh APFS scan")

                        Button(action: { startTargetedDeveloperScan() }) {
                            HStack(spacing: 5) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text("SMART SCAN")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color(red: 1.00, green: 0.40, blue: 0.42))
                            .foregroundColor(.black)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                            .shadow(color: .black, radius: 0, x: 2, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let dbPath = home.appendingPathComponent("Library/Application Support/Reclaim/reclaim.db").path
            if let db = try? Database(path: dbPath) {
                let receipts = db.fetchReceipts(limit: 50)
                appState.setHistoricalReceipts(receipts)
            }
            if CommandLine.arguments.contains("--scan") {
                startTargetedDeveloperScan()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReclaimSlownessAlert"))) { notif in
            if let msg = notif.object as? String {
                appState.triggerSlownessAlert(msg)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReclaimNavigateToInsights"))) { _ in
            selectedSection = .pressureInsights
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List(selection: $selectedSection) {
            Section("Core") {
                NavigationLink(value: NavigationSection.smartScan) {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 24, height: 24)
                            .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))

                        Text("Smart Scan")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                    }
                }

                NavigationLink(value: NavigationSection.systemStorage) {
                    HStack(spacing: 10) {
                        Image(systemName: "internaldrive.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 24, height: 24)
                            .background(Color(red: 0.32, green: 0.81, blue: 0.40))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))

                        Text("macOS Storage")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                    }
                }
            }

            Section("Developer Toolchains") {
                categorySidebarLink(category: .xcode,    section: .xcode,    icon: "hammer.fill",            color: .blue)
                categorySidebarLink(category: .docker,   section: .docker,   icon: "shippingbox.fill",       color: .cyan)
                categorySidebarLink(category: .node,     section: .node,     icon: "cube.box.fill",          color: .green)
                categorySidebarLink(category: .gradle,   section: .gradle,   icon: "cup.and.saucer.fill",    color: .orange)
                categorySidebarLink(category: .homebrew, section: .homebrew, icon: "mug.fill",               color: .yellow)
                categorySidebarLink(category: .ruby,     section: .ruby,     icon: "diamond.fill",           color: .red)
                categorySidebarLink(category: .jvm,      section: .jvm,      icon: "coffee.fill",            color: Color(red: 0.55, green: 0.35, blue: 0.15))
                categorySidebarLink(category: .rust,     section: .rust,     icon: "gearshape.2.fill",       color: .orange)
            }

            Section("AI & Machine Learning") {
                categorySidebarLink(category: .llm,          section: .llm,          icon: "brain.head.profile", color: .purple)
                categorySidebarLink(category: .mlFrameworks, section: .mlFrameworks, icon: "waveform.path.ecg",  color: Color(red: 0.7, green: 0.2, blue: 0.9))
                categorySidebarLink(category: .pythonEnv,    section: .pythonEnv,    icon: "terminal.fill",      color: .teal)
            }

            Section("Developer Tuning & Power Tools") {
                NavigationLink(value: NavigationSection.tweaks) {
                    sidebarItemRow(icon: "slider.horizontal.3", title: "Developer Tweaks", color: Color(red: 0.85, green: 0.45, blue: 0.95))
                }

                NavigationLink(value: NavigationSection.daemons) {
                    sidebarItemRow(icon: "cpu.fill", title: "Background Daemons", color: Color(red: 0.30, green: 0.70, blue: 0.90))
                }

                NavigationLink(value: NavigationSection.duplicates) {
                    sidebarItemRow(icon: "square.on.square.dashed", title: "Duplicate Assets", color: Color(red: 1.00, green: 0.60, blue: 0.20))
                }
            }

            Section("System Utilities") {
                NavigationLink(value: NavigationSection.uninstaller) {
                    sidebarItemRow(icon: "app.badge.fill", title: "App Uninstaller", color: Color(red: 1.00, green: 0.40, blue: 0.42))
                }

                NavigationLink(value: NavigationSection.maintenance) {
                    sidebarItemRow(icon: "wrench.and.screwdriver.fill", title: "Maintenance", color: Color(red: 0.35, green: 0.75, blue: 1.0))
                }

                NavigationLink(value: NavigationSection.shredder) {
                    sidebarItemRow(icon: "flame.fill", title: "File Shredder", color: Color(red: 1.00, green: 0.40, blue: 0.42))
                }

                categorySidebarLink(category: .backups, section: .backups, icon: "externaldrive.fill.badge.icloud", color: .indigo)

                NavigationLink(value: NavigationSection.largeFiles) {
                    sidebarItemRow(icon: "scalemass.fill", title: "Large & Old Files", color: Color(red: 1.00, green: 0.72, blue: 0.18))
                }

                NavigationLink(value: NavigationSection.explorer) {
                    sidebarItemRow(icon: "list.bullet.indent", title: "Storage Explorer", color: Color(red: 0.32, green: 0.81, blue: 0.40))
                }

                NavigationLink(value: NavigationSection.history) {
                    sidebarItemRow(icon: "clock.arrow.circlepath", title: "Receipts & History", color: Color(red: 0.40, green: 0.88, blue: 0.60))
                }

                NavigationLink(value: NavigationSection.pressureInsights) {
                    sidebarItemRow(icon: "stethoscope", title: "Pressure & Health", color: Color(red: 0.0, green: 0.90, blue: 1.0))
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(Color(red: 0.22, green: 0.78, blue: 0.52))
                            .font(.system(size: 13, weight: .bold))
                        Text("SafetyEngine Active")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                    }

                    Text("Credentials, .ssh, .env & checkpoints immune.")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Color.black.opacity(0.65))
                }
                .padding(10)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
                .shadow(color: .black, radius: 0, x: 2, y: 2)
                .padding(.vertical, 4)
            }
        }
        .listStyle(.sidebar)
    }

    private func sidebarItemRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 22, height: 22)
                .background(color)
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.5))

            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.black)
        }
    }

    private func categorySidebarLink(category: StorageCategory, section: NavigationSection, icon: String, color: Color) -> some View {
        let items = appState.storageItems.filter { $0.category == category }
        let total = items.reduce(0) { $0 + $1.estimatedReclaimableSize }

        return NavigationLink(value: section) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 22, height: 22)
                    .background(color)
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.5))

                Text(category.displayName)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.black)

                Spacer()

                if total > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                        .foregroundColor(.black)
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1.2))
                }
            }
        }
    }

    // MARK: - Detail View Router

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection {
        case .smartScan, .none:
            SmartScanView(
                appState: appState,
                theme: themeManager.currentTheme,
                onStartScan: { startTargetedDeveloperScan() },
                onStopScan: cancelScan,
                onExecuteClean: executeCleanSelected,
                onDeleteItem: deleteSingleItem,
                onOpenStorageManager: {
                    selectedSection = .systemStorage
                }
            )
        case .systemStorage:
            SystemStorageView(
                appState: appState,
                theme: themeManager.currentTheme,
                onNavigateToSection: { section in
                    selectedSection = section
                },
                onTriggerCategoryScan: { category in
                    startTargetedDeveloperScan(category: category)
                }
            )
        // Developer Ecosystems
        case .xcode:        EcosystemCleanerView(category: .xcode,        appState: appState, theme: themeManager.currentTheme, onScanCategory: { startTargetedDeveloperScan(category: .xcode) },        onDeleteItem: deleteSingleItem)
        case .docker:       EcosystemCleanerView(category: .docker,       appState: appState, theme: themeManager.currentTheme, onScanCategory: { startTargetedDeveloperScan(category: .docker) },       onDeleteItem: deleteSingleItem)
        case .node:         EcosystemCleanerView(category: .node,         appState: appState, theme: themeManager.currentTheme, onScanCategory: { startTargetedDeveloperScan(category: .node) },         onDeleteItem: deleteSingleItem)
        case .gradle:       EcosystemCleanerView(category: .gradle,       appState: appState, theme: themeManager.currentTheme, onScanCategory: { startTargetedDeveloperScan(category: .gradle) },       onDeleteItem: deleteSingleItem)
        case .homebrew:     EcosystemCleanerView(category: .homebrew,     appState: appState, theme: themeManager.currentTheme, onScanCategory: { startTargetedDeveloperScan(category: .homebrew) },     onDeleteItem: deleteSingleItem)
        case .ruby:         EcosystemCleanerView(category: .ruby,         appState: appState, theme: themeManager.currentTheme, onScanCategory: { startTargetedDeveloperScan(category: .ruby) },         onDeleteItem: deleteSingleItem)
        case .jvm:          EcosystemCleanerView(category: .jvm,          appState: appState, theme: themeManager.currentTheme, onScanCategory: { startTargetedDeveloperScan(category: .jvm) },          onDeleteItem: deleteSingleItem)
        case .rust:         EcosystemCleanerView(category: .rust,         appState: appState, theme: themeManager.currentTheme, onScanCategory: { startTargetedDeveloperScan(category: .rust) },         onDeleteItem: deleteSingleItem)
        // AI / ML
        case .llm:          EcosystemCleanerView(category: .llm,          appState: appState, theme: themeManager.currentTheme, onScanCategory: { startTargetedDeveloperScan(category: .llm) },          onDeleteItem: deleteSingleItem)
        case .mlFrameworks: EcosystemCleanerView(category: .mlFrameworks, appState: appState, theme: themeManager.currentTheme, onScanCategory: { startTargetedDeveloperScan(category: .mlFrameworks) },   onDeleteItem: deleteSingleItem)
        case .pythonEnv:    EcosystemCleanerView(category: .pythonEnv,    appState: appState, theme: themeManager.currentTheme, onScanCategory: { startTargetedDeveloperScan(category: .pythonEnv) },    onDeleteItem: deleteSingleItem)
        // System
        case .uninstaller:  AppUninstallerView(appState: appState, theme: themeManager.currentTheme)
        case .maintenance:  MaintenanceView(appState: appState, theme: themeManager.currentTheme)
        case .shredder:     FileShredderView(appState: appState, theme: themeManager.currentTheme)
        case .backups:      EcosystemCleanerView(category: .backups,      appState: appState, theme: themeManager.currentTheme, onScanCategory: { startTargetedDeveloperScan(category: .backups) },      onDeleteItem: deleteSingleItem)
        case .largeFiles:   LargeFilesView(appState: appState, theme: themeManager.currentTheme, onDeleteItem: deleteSingleItem)
        // Developer Tuning & Power Tools
        case .tweaks:       DeveloperTweaksView(appState: appState, themeManager: themeManager)
        case .daemons:      LaunchAgentsView(appState: appState, themeManager: themeManager)
        case .duplicates:   DuplicateAssetsView(appState: appState, themeManager: themeManager)
        case .explorer:         ExplorerView(appState: appState, theme: themeManager.currentTheme, onDeleteItem: deleteSingleItem)
        case .history:          ReceiptsHistoryView(appState: appState, theme: themeManager.currentTheme)
        case .pressureInsights: PressureInsightsView(appState: appState, themeManager: themeManager)
        }
    }

    // MARK: - Fast Developer Scanning Engine

    private func startTargetedDeveloperScan(category: StorageCategory? = nil) {
        cancelScan()
        appState.beginScan(for: category)

        activeScanTask = Task {
            let container = await DependencyContainer.createWithDefaultAnalyzers()
            let coordinator = ScanCoordinator(analyzerRegistry: container.analyzerRegistry)

            let home = FileManager.default.homeDirectoryForCurrentUser

            // ─────────────────────────────────────────────────────────────────
            // Intelligence-driven targeted scan — covers ALL developer personas:
            // Standard developer, AI scientist, ML engineer, data scientist,
            // software engineer, model trainer, full-stack developer.
            //
            // Scans ONLY the exact known waste hotspots — never broad trees.
            // ─────────────────────────────────────────────────────────────────
            let categoryPaths: [StorageCategory: [URL]] = [
                .xcode: [
                    home.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
                    home.appendingPathComponent("Library/Developer/Xcode/Archives"),
                    home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"),
                    home.appendingPathComponent("Library/Developer/Xcode/macOS DeviceSupport"),
                    home.appendingPathComponent("Library/Developer/CoreSimulator/Caches"),
                    home.appendingPathComponent("Library/Developer/CoreSimulator/Profiles/Runtimes"),
                ],
                .docker: [
                    home.appendingPathComponent("Library/Containers/com.docker.docker/Data/vms"),
                    home.appendingPathComponent("Library/Containers/com.docker.docker/Data/docker-buildkit"),
                    home.appendingPathComponent(".docker"),
                ],
                .gradle: [
                    home.appendingPathComponent(".gradle/caches"),
                    home.appendingPathComponent(".gradle/wrapper"),
                    home.appendingPathComponent(".gradle/daemon"),
                ],
                .node: [
                    home.appendingPathComponent(".npm"),
                    home.appendingPathComponent(".yarn/cache"),
                    home.appendingPathComponent("Library/Caches/Yarn"),
                    home.appendingPathComponent(".pnpm-store"),
                    home.appendingPathComponent(".bun"),
                    home.appendingPathComponent("Library/Caches/ms-playwright"),
                    home.appendingPathComponent(".cache/puppeteer"),
                ],
                .homebrew: [
                    home.appendingPathComponent("Library/Caches/Homebrew"),
                ],
                .maven: [
                    home.appendingPathComponent(".m2/repository"),
                ],
                .ruby: [
                    home.appendingPathComponent(".rbenv/versions"),
                    home.appendingPathComponent(".rvm"),
                    home.appendingPathComponent(".gem"),
                ],
                .jvm: [
                    URL(fileURLWithPath: "/Library/Java/JavaVirtualMachines"),
                    home.appendingPathComponent("Library/Java/JavaVirtualMachines"),
                    home.appendingPathComponent(".konan"),
                    home.appendingPathComponent(".ivy2/cache"),
                    home.appendingPathComponent(".sbt"),
                    home.appendingPathComponent(".cache/coursier"),
                ],
                .rust: [
                    home.appendingPathComponent(".cargo/registry"),
                    home.appendingPathComponent(".cargo/git"),
                ],
                .llm: [
                    home.appendingPathComponent(".ollama/models"),
                    home.appendingPathComponent("Library/Application Support/LM Studio/models"),
                    home.appendingPathComponent("Library/Application Support/Jan/models"),
                    home.appendingPathComponent(".cache/gpt4all"),
                    home.appendingPathComponent(".cache/huggingface/hub"),
                ],
                .mlFrameworks: [
                    home.appendingPathComponent(".cache/torch"),
                    home.appendingPathComponent(".cache/huggingface/datasets"),
                    home.appendingPathComponent(".triton"),
                    home.appendingPathComponent(".keras"),
                    home.appendingPathComponent(".cache/tfhub_modules"),
                    home.appendingPathComponent(".cache/onnxruntime"),
                    home.appendingPathComponent(".dvc/cache"),
                    home.appendingPathComponent(".cache/dvc"),
                ],
                .pythonEnv: [
                    home.appendingPathComponent(".pyenv/versions"),
                    home.appendingPathComponent("miniconda3/pkgs"),
                    home.appendingPathComponent("miniconda3/envs"),
                    home.appendingPathComponent("anaconda3/pkgs"),
                    home.appendingPathComponent("anaconda3/envs"),
                    home.appendingPathComponent(".conda"),
                    home.appendingPathComponent(".cache/pip"),
                    home.appendingPathComponent("Library/Caches/pip"),
                    home.appendingPathComponent(".cache/uv"),
                    home.appendingPathComponent(".cache/pypoetry"),
                    home.appendingPathComponent("Library/Caches/pypoetry"),
                    home.appendingPathComponent(".tox"),
                ],
                .backups: [
                    home.appendingPathComponent("Library/Application Support/MobileSync/Backup"),
                ],
                .downloads: [
                    home.appendingPathComponent("Downloads"),
                ]
            ]

            let candidateUrls: [URL]
            if let cat = category {
                candidateUrls = categoryPaths[cat] ?? []
            } else {
                candidateUrls = Array(categoryPaths.values.joined())
            }

            let targetPaths = candidateUrls.filter { FileManager.default.fileExists(atPath: $0.path) }

            // Persistent database for mtime caching
            let appSupportDir = home.appendingPathComponent("Library/Application Support/Reclaim")
            try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
            let dbPath = appSupportDir.appendingPathComponent("reclaim.db").path
            let db = try? Database(path: dbPath)

            await MainActor.run {
                let catName = category?.displayName ?? "ALL DEVELOPER VECTORS"
                appState.appendTerminalLog("[scan:start] Launching targeted APFS scan for: \(catName)...", level: .info)
            }

            var buffer: [StorageItem] = []
            var filesCount = 0
            var bytesTotal: Int64 = 0
            let start = Date()
            var lastUIUpdateTime = Date()

            // Heavy cache folders that should be aggregated as single units instead of crawling 50,000 files
            let aggregateRoots: Set<String> = [
                home.appendingPathComponent(".npm").path,
                home.appendingPathComponent(".gradle/caches").path,
                home.appendingPathComponent(".gradle/wrapper").path,
                home.appendingPathComponent(".gradle/daemon").path,
                home.appendingPathComponent(".m2/repository").path,
                home.appendingPathComponent(".yarn/cache").path,
                home.appendingPathComponent("Library/Caches/Yarn").path,
                home.appendingPathComponent(".pnpm-store").path,
                home.appendingPathComponent(".bun").path,
                home.appendingPathComponent("Library/Caches/ms-playwright").path,
                home.appendingPathComponent(".cache/puppeteer").path,
                home.appendingPathComponent("Library/Caches/Homebrew").path,
                home.appendingPathComponent("Library/Developer/CoreSimulator/Caches").path,
                home.appendingPathComponent(".cache/torch").path,
                home.appendingPathComponent(".triton").path,
                home.appendingPathComponent(".keras").path,
                home.appendingPathComponent(".cache/tfhub_modules").path,
                home.appendingPathComponent(".cache/onnxruntime").path,
                home.appendingPathComponent(".cache/pip").path,
                home.appendingPathComponent("Library/Caches/pip").path,
                home.appendingPathComponent(".cache/uv").path,
                home.appendingPathComponent(".cache/pypoetry").path,
                home.appendingPathComponent("Library/Caches/pypoetry").path,
                home.appendingPathComponent(".cache/coursier").path,
                home.appendingPathComponent(".ivy2/cache").path,
                home.appendingPathComponent(".konan").path,
            ]

            let downloadsPath = home.appendingPathComponent("Downloads").path

            // Container directories whose immediate children are discrete user entities
            // (e.g. HuggingFace models, DerivedData projects, pyenv versions, conda envs)
            let containerRoots: Set<String> = [
                home.appendingPathComponent(".cache/huggingface/hub").path,
                home.appendingPathComponent("Library/Developer/Xcode/DerivedData").path,
                home.appendingPathComponent("Library/Developer/Xcode/Archives").path,
                home.appendingPathComponent(".pyenv/versions").path,
                home.appendingPathComponent("miniconda3/envs").path,
                home.appendingPathComponent("anaconda3/envs").path,
                home.appendingPathComponent(".rbenv/versions").path,
                home.appendingPathComponent(".ollama/models/manifests").path,
            ]

            for targetURL in targetPaths {
                if Task.isCancelled { break }
                let path = targetURL.path

                // 1. Special fast handling for Downloads (only surface items >= 50MB or archives)
                if path == downloadsPath {
                    let archiveExts: Set<String> = ["dmg", "iso", "xip", "pkg", "mpkg", "zip", "tar", "gz", "tgz"]
                    guard let entries = try? FileManager.default.contentsOfDirectory(at: targetURL, includingPropertiesForKeys: [.fileSizeKey, .totalFileAllocatedSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else { continue }

                    for fileURL in entries {
                        if Task.isCancelled { break }
                        let filePath = fileURL.path
                        var isDir: ObjCBool = false
                        guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDir) else { continue }

                        let ext = fileURL.pathExtension.lowercased()
                        var allocatedBytes: Int64 = 0
                        if isDir.boolValue {
                            if ext == "app" || ext == "pkg" {
                                let (sz, _) = FileScanner.calculateDirectorySize(at: filePath)
                                allocatedBytes = sz
                            } else {
                                continue
                            }
                        } else {
                            var st = stat()
                            if lstat(filePath, &st) == 0 {
                                allocatedBytes = Int64(st.st_blocks) * 512
                            }
                        }

                        // Surface if >= 50MB or if it is an installer image/archive
                        if allocatedBytes >= 50 * 1024 * 1024 || (archiveExts.contains(ext) && allocatedBytes >= 5 * 1024 * 1024) {
                            let dummyItem = StorageItem(
                                path: filePath,
                                logicalSize: allocatedBytes,
                                allocatedSize: allocatedBytes,
                                category: .downloads,
                                risk: .low,
                                recoverability: .redownloadable,
                                whatIsThis: "Downloaded installer or archive (\(ext.uppercased()))"
                            )
                            let analysis = await coordinator.analyzerRegistry.analyze(item: dummyItem, context: AnalysisContext(rootURL: fileURL))
                            let safeResult = coordinator.safetyEngine.assess(result: analysis)

                            buffer.append(safeResult.item)
                            filesCount += 1
                            bytesTotal += allocatedBytes

                            await MainActor.run {
                                let szStr = ByteCountFormatter.string(fromByteCount: allocatedBytes, countStyle: .file)
                                appState.appendTerminalLog("[downloads] \(fileURL.lastPathComponent): \(szStr)", level: .info)
                            }
                        }
                    }
                    continue
                }

                // 2. Container directories (enumerate each child entity and compute live size)
                if containerRoots.contains(path) {
                    guard let subEntries = try? FileManager.default.contentsOfDirectory(at: targetURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { continue }

                    for childURL in subEntries {
                        if Task.isCancelled { break }
                        let childPath = childURL.path
                        var isDir: ObjCBool = false
                        guard FileManager.default.fileExists(atPath: childPath, isDirectory: &isDir) else { continue }

                        let allocatedBytes: Int64
                        let count: Int
                        if isDir.boolValue {
                            let calculated = FileScanner.calculateDirectorySize(at: childPath)
                            allocatedBytes = calculated.allocatedBytes
                            count = calculated.fileCount
                        } else {
                            var st = stat()
                            if lstat(childPath, &st) == 0 {
                                allocatedBytes = Int64(st.st_blocks) * 512
                            } else {
                                allocatedBytes = 0
                            }
                            count = 1
                        }

                        guard allocatedBytes > 0 else { continue }

                        let dummyItem = StorageItem(
                            path: childPath,
                            logicalSize: allocatedBytes,
                            allocatedSize: allocatedBytes,
                            category: coordinator.categorizer.categorize(path: childPath),
                            risk: .low,
                            recoverability: .redownloadable,
                            whatIsThis: "\(childURL.lastPathComponent)"
                        )
                        let analysis = await coordinator.analyzerRegistry.analyze(item: dummyItem, context: AnalysisContext(rootURL: childURL))
                        let safeResult = coordinator.safetyEngine.assess(result: analysis)

                        buffer.append(safeResult.item)
                        filesCount += count
                        bytesTotal += allocatedBytes

                        let now = Date()
                        if buffer.count >= 10 || now.timeIntervalSince(lastUIUpdateTime) >= 0.15 {
                            let chunk = buffer
                            buffer.removeAll(keepingCapacity: true)
                            lastUIUpdateTime = now

                            await MainActor.run {
                                appState.appendItems(chunk)
                                var prog = ScanProgress()
                                prog.filesScanned = filesCount
                                prog.bytesIndexed = bytesTotal
                                prog.currentPath = childPath
                                prog.elapsedSeconds = now.timeIntervalSince(start)
                                appState.updateProgress(prog)

                                let szStr = ByteCountFormatter.string(fromByteCount: allocatedBytes, countStyle: .file)
                                appState.appendTerminalLog("[entity] \(childURL.lastPathComponent): \(szStr)", level: .info)
                            }
                        }
                    }
                    continue
                }

                // 3. Check if this is a known aggregate cache root
                if aggregateRoots.contains(path) {
                    var st = stat()
                    let diskMtime: Double
                    if lstat(path, &st) == 0 {
                        diskMtime = Double(st.st_mtimespec.tv_sec) + Double(st.st_mtimespec.tv_nsec) / 1_000_000_000
                    } else {
                        diskMtime = 0
                    }

                    // Always calculate live directory size on scan so deletions/disk changes are immediately detected!
                    let calculated = FileScanner.calculateDirectorySize(at: path)
                    let allocatedBytes = calculated.allocatedBytes
                    let count = calculated.fileCount
                    db?.updateDirectoryCache(for: path, mtime: diskMtime, allocatedBytes: allocatedBytes, fileCount: count)

                    if allocatedBytes > 0 {
                        let context = AnalysisContext(rootURL: targetURL)
                        let rawItem = StorageItem(
                            path: path,
                            logicalSize: allocatedBytes,
                            allocatedSize: allocatedBytes,
                            category: coordinator.categorizer.categorize(path: path),
                            risk: .safe,
                            recoverability: .regeneratable,
                            whatIsThis: "\(targetURL.lastPathComponent) Cache Directory"
                        )
                        let analysis = await coordinator.analyzerRegistry.analyze(item: rawItem, context: context)
                        let safeResult = coordinator.safetyEngine.assess(result: analysis)

                        buffer.append(safeResult.item)
                        filesCount += count
                        bytesTotal += allocatedBytes

                        await MainActor.run {
                            let szStr = ByteCountFormatter.string(fromByteCount: allocatedBytes, countStyle: .file)
                            appState.appendTerminalLog("[c++:fts] \(targetURL.lastPathComponent): \(szStr) (\(count) files)", level: .info)
                        }
                    } else {
                        // Directory is 0 bytes (empty or deleted)
                        db?.invalidateCache(for: path)
                    }
                    continue
                }

                // 3. For directories with sub-items (like DerivedData, LLM models, pyenv versions)
                let context = AnalysisContext(rootURL: targetURL)
                for await result in coordinator.scanAndAnalyze(rootURL: targetURL, context: context, maxDepth: 2) {
                    if Task.isCancelled { break }

                    buffer.append(result.item)
                    filesCount += 1
                    bytesTotal += result.item.allocatedSize

                    let now = Date()
                    if buffer.count >= 20 || now.timeIntervalSince(lastUIUpdateTime) >= 0.15 {
                        let chunk = buffer
                        buffer.removeAll(keepingCapacity: true)
                        lastUIUpdateTime = now

                        await MainActor.run {
                            appState.appendItems(chunk)
                            var prog = ScanProgress()
                            prog.filesScanned = filesCount
                            prog.bytesIndexed = bytesTotal
                            prog.currentPath = result.item.path
                            prog.elapsedSeconds = now.timeIntervalSince(start)
                            appState.updateProgress(prog)

                            let szStr = ByteCountFormatter.string(fromByteCount: result.item.allocatedSize, countStyle: .file)
                            let fileName = URL(fileURLWithPath: result.item.path).lastPathComponent
                            appState.appendTerminalLog("[0x\(String(format: "%08x", abs(result.item.path.hashValue) & 0xFFFFFFFF))] \(fileName): \(szStr)", level: .info)
                        }
                    }
                }
            }

            if !buffer.isEmpty && !Task.isCancelled {
                let remaining = buffer
                await MainActor.run {
                    appState.appendItems(remaining)
                }
            }

            // ─────────────────────────────────────────────────────────────────
            // 4. Project Workspace Sprawl Scanner:
            // Searches user repositories & workspaces for project node_modules
            // and Python virtual environments (.venv, venv, env)
            // ─────────────────────────────────────────────────────────────────
            let shouldScanNodeWorkspaces = (category == nil || category == .node)
            let shouldScanPythonWorkspaces = (category == nil || category == .pythonEnv)

            if (shouldScanNodeWorkspaces || shouldScanPythonWorkspaces) && !Task.isCancelled {
                await MainActor.run {
                    appState.appendTerminalLog("[c++:workspace] Crawling developer project roots for node_modules & virtualenvs...", level: .header)
                }

                let workspaceRoots = ProjectWorkspaceScanner.defaultWorkspaceRoots(home: home)
                let discoveredItems = ProjectWorkspaceScanner.scanWorkspaces(
                    roots: workspaceRoots,
                    scanNode: shouldScanNodeWorkspaces,
                    scanPython: shouldScanPythonWorkspaces,
                    maxDepth: 4
                )

                var projectBuffer: [StorageItem] = []
                for item in discoveredItems {
                    if Task.isCancelled { break }
                    let safeResult = coordinator.safetyEngine.assess(item: item)
                    projectBuffer.append(safeResult)
                    filesCount += 1
                    bytesTotal += safeResult.allocatedSize

                    await MainActor.run {
                        let szStr = ByteCountFormatter.string(fromByteCount: safeResult.allocatedSize, countStyle: .file)
                        let prefix = safeResult.category == .node ? "[node:modules]" : "[python:venv]"
                        let tag = URL(fileURLWithPath: safeResult.path).deletingLastPathComponent().lastPathComponent
                        let folder = URL(fileURLWithPath: safeResult.path).lastPathComponent
                        appState.appendTerminalLog("\(prefix) \(tag)/\(folder): \(szStr)", level: .info)
                    }
                }

                if !projectBuffer.isEmpty && !Task.isCancelled {
                    let chunk = projectBuffer
                    await MainActor.run {
                        appState.appendItems(chunk)
                        var prog = ScanProgress()
                        prog.filesScanned = filesCount
                        prog.bytesIndexed = bytesTotal
                        prog.elapsedSeconds = Date().timeIntervalSince(start)
                        appState.updateProgress(prog)
                    }
                }
            }

            await MainActor.run {
                if Task.isCancelled {
                    appState.resetScan()
                    appState.appendTerminalLog("[scan:cancel] Scan aborted by user interrupt.", level: .warning)
                } else {
                    appState.completeScan()
                    let totalStr = ByteCountFormatter.string(fromByteCount: bytesTotal, countStyle: .file)
                    appState.appendTerminalLog("[scan:complete] Traversed \(filesCount) targets. Total potential reclaim: \(totalStr).", level: .success)
                }
            }
        }
    }

    private func cancelScan() {
        activeScanTask?.cancel()
        activeScanTask = nil
        appState.resetScan()
        appState.appendTerminalLog("[scan:stopped] Active scan task terminated.", level: .warning)
    }

    private func forceRescan() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dbPath = home.appendingPathComponent("Library/Application Support/Reclaim/reclaim.db").path
        if let db = try? Database(path: dbPath) {
            db.clearDirectoryCache()
        }
        appState.clearTerminalLogs()
        appState.appendTerminalLog("[c++:rescan] Directory cache purged. Starting fresh APFS inode traversal...", level: .warning)
        startTargetedDeveloperScan(category: nil)
    }

    // MARK: - Clean Execution (Safe Trash-First)

    private func executeCleanSelected() {
        let selectedIDs = appState.selectedItemIDs
        let itemsToClean = appState.storageItems.filter { selectedIDs.contains($0.id) }

        guard !itemsToClean.isEmpty else { return }

        appState.appendTerminalLog("[clean:begin] Purging \(itemsToClean.count) selected items (\(appState.formattedSelectedBytes))...", level: .warning)

        let candidates = itemsToClean.map { CleanupCandidate(item: $0) }
        let plan = ReclaimPlan(targetBytes: appState.selectedBytes, candidates: candidates)
        let executor = CleanupExecutor(useTrash: true)

        do {
            let receipt = try executor.execute(plan: plan)
            let successfullyRemovedPaths = Set(receipt.actions.filter(\.success).map(\.path))
            let removedIDs = itemsToClean.filter { successfullyRemovedPaths.contains($0.path) }.map(\.id)

            // Invalidate SQLite directory cache for all deleted paths
            let home = FileManager.default.homeDirectoryForCurrentUser
            let dbPath = home.appendingPathComponent("Library/Application Support/Reclaim/reclaim.db").path
            if let db = try? Database(path: dbPath) {
                try? db.save(receipt: receipt)
                for path in successfullyRemovedPaths {
                    db.invalidateCache(for: path)
                }
            }

            appState.removeItems(withIDs: Set(removedIDs))
            appState.recordReceipt(receipt)

            let recoveredStr = ByteCountFormatter.string(fromByteCount: receipt.actualRecoveredBytes, countStyle: .file)
            appState.appendTerminalLog("[clean:ok] Safely moved \(receipt.actions.filter(\.success).count) items to ~/.Trash. Recovered: \(recoveredStr).", level: .success)
            appState.appendTerminalLog("[clean:cache] Cache invalidated for removed directories.", level: .info)
        } catch {
            appState.failScan(reason: "Cleanup failed: \(error.localizedDescription)")
            appState.appendTerminalLog("[clean:err] Execution failed: \(error.localizedDescription)", level: .error)
        }
    }

    private func deleteSingleItem(_ item: StorageItem) {
        appState.appendTerminalLog("[trash:item] Trashing: \(item.path)...", level: .warning)
        let candidate = CleanupCandidate(item: item)
        let plan = ReclaimPlan(targetBytes: item.estimatedReclaimableSize, candidates: [candidate])
        let executor = CleanupExecutor(useTrash: true)

        do {
            let receipt = try executor.execute(plan: plan)
            if let action = receipt.actions.first, action.success {
                let home = FileManager.default.homeDirectoryForCurrentUser
                let dbPath = home.appendingPathComponent("Library/Application Support/Reclaim/reclaim.db").path
                if let db = try? Database(path: dbPath) {
                    try? db.save(receipt: receipt)
                    db.invalidateCache(for: item.path)
                }
                appState.removeItems(withIDs: [item.id])
                appState.recordReceipt(receipt)
                let sizeStr = ByteCountFormatter.string(fromByteCount: item.allocatedSize, countStyle: .file)
                let fileName = URL(fileURLWithPath: item.path).lastPathComponent
                appState.appendTerminalLog("[trash:ok] \(fileName) (\(sizeStr)) moved to Trash. Cache invalidated.", level: .success)
            }
        } catch {
            print("Failed to delete item: \(item.path)")
            appState.appendTerminalLog("[trash:err] Failed to delete: \(error.localizedDescription)", level: .error)
        }
    }
}
