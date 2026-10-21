// CppTerminalView.swift
// ReclaimUI/Components
//
// Integrated C++ Developer Terminal Console ("Second Terminal").
// Simulates an authentic C++ compiler & runtime terminal environment where developers
// inspect low-level APFS inode traversal, SQLite cache invalidation, and trash-first execution.
// Supports interactive commands (help, scan, clean, cache clear, status, etc.).

import SwiftUI
import Reclaim

public struct CppTerminalView: View {
    @ObservedObject public var appState: AppState
    public let theme: any Theme
    public let onStartScan: (StorageCategory?) -> Void
    public let onExecuteClean: () -> Void
    public let onForceRescan: () -> Void

    @State private var isExpanded: Bool = false
    @State private var commandInput: String = ""

    public init(
        appState: AppState,
        theme: any Theme,
        onStartScan: @escaping (StorageCategory?) -> Void,
        onExecuteClean: @escaping () -> Void,
        onForceRescan: @escaping () -> Void
    ) {
        self.appState = appState
        self.theme = theme
        self.onStartScan = onStartScan
        self.onExecuteClean = onExecuteClean
        self.onForceRescan = onForceRescan
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header / Tab Bar (Neo-Brutalist Drawer Bar)
            headerBar

            // Collapsible Terminal Body
            if isExpanded {
                VStack(spacing: 0) {
                    quickActionsBar
                    Divider().background(Color.black.opacity(0.2))
                    logStreamView
                    Divider().background(Color.black.opacity(0.2))
                    commandPromptBar
                }
                .frame(height: 220)
                .background(Color(red: 0.08, green: 0.09, blue: 0.11))
            }
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 2)
                .foregroundColor(Color.black),
            alignment: .top
        )
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            // Terminal tab indicator (Neo-Brutal Badge)
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 22, height: 22)
                        .background(Color(red: 0.22, green: 0.78, blue: 0.52)) // Mint
                        .cornerRadius(5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.5))

                    Text("DIAGNOSTICS & SYSTEM TERMINAL")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.black)

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.black)
                }
            }
            .buttonStyle(.plain)

            // Engine status badges
            HStack(spacing: 6) {
                Text("APFS fts: ONLINE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                    .foregroundColor(.black)
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1.2))

                Text("TRASH-FIRST: 0-RISK")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.22, green: 0.78, blue: 0.52))
                    .foregroundColor(.black)
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1.2))

                if !appState.terminalLogs.isEmpty {
                    Text("\(appState.terminalLogs.count) LOGS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.black.opacity(0.6))
                }
            }

            Spacer()

            // Header actions
            HStack(spacing: 8) {
                Button(action: { appState.clearTerminalLogs() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                        Text("Clear")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                    .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                }
                .buttonStyle(.plain)

                Button(action: {
                    let text = appState.terminalLogs.map { "[\($0.timestamp.formatted(date: .omitted, time: .standard))] \($0.text)" }.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                        Text("Copy")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                    .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white)
    }

    // MARK: - Quick Action Buttons

    private var quickActionsBar: some View {
        HStack(spacing: 8) {
            Text("QUICK ACTIONS:")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(Color(red: 0.65, green: 0.70, blue: 0.80))

            quickButton("./reclaim --scan", color: Color(red: 0.35, green: 0.75, blue: 1.0)) {
                executeCommand("./reclaim --scan")
            }

            quickButton("./reclaim --rescan-fresh", color: Color(red: 0.70, green: 0.50, blue: 0.98)) {
                executeCommand("./reclaim --rescan-fresh")
            }

            quickButton("./reclaim --docker", color: Color(red: 0.35, green: 0.85, blue: 0.85)) {
                executeCommand("./reclaim --docker")
            }

            quickButton("./reclaim --node", color: Color(red: 0.40, green: 0.88, blue: 0.60)) {
                executeCommand("./reclaim --node")
            }

            if appState.selectedBytes > 0 {
                quickButton("./reclaim --clean", color: Color(red: 1.00, green: 0.40, blue: 0.42)) {
                    executeCommand("./reclaim --clean")
                }
            }

            quickButton("cache --clear", color: Color(red: 1.00, green: 0.72, blue: 0.18)) {
                executeCommand("cache clear")
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(red: 0.12, green: 0.14, blue: 0.18))
    }

    private func quickButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color)
                .foregroundColor(.black)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.black, lineWidth: 1.2)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Log Stream View

    private var logStreamView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(appState.terminalLogs) { log in
                        HStack(alignment: .top, spacing: 6) {
                            Text(log.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(red: 0.35, green: 0.40, blue: 0.48))

                            Text(log.text)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(color(for: log.level))
                                .textSelection(.enabled)
                        }
                        .id(log.id)
                    }
                }
                .padding(8)
            }
            .onChange(of: appState.terminalLogs.count) { _ in
                if let lastID = appState.terminalLogs.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Interactive Command Prompt

    private var commandPromptBar: some View {
        HStack(spacing: 6) {
            Text("reclaim@darwin:~$")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.30, green: 0.85, blue: 0.50))

            TextField("type command (e.g. help, scan, clean, cache clear, status, ls)", text: $commandInput)
                .font(.system(size: 11, design: .monospaced))
                .textFieldStyle(.plain)
                .foregroundColor(Color(red: 0.90, green: 0.93, blue: 0.96))
                .onSubmit {
                    let cmd = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cmd.isEmpty else { return }
                    executeCommand(cmd)
                    commandInput = ""
                }

            if !commandInput.isEmpty {
                Button(action: {
                    let cmd = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cmd.isEmpty else { return }
                    executeCommand(cmd)
                    commandInput = ""
                }) {
                    Text("RUN")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(red: 0.06, green: 0.08, blue: 0.11))
    }

    // MARK: - Command Execution Engine

    private func executeCommand(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        appState.appendTerminalLog("$ \(trimmed)", level: .command)

        let tokens = trimmed.lowercased().split(separator: " ").map(String.init)
        guard let primary = tokens.first else { return }

        switch primary {
        case "help", "-h", "--help":
            appState.appendTerminalLog("RECLAIM C++ COMMAND REFERENCE:", level: .header)
            appState.appendTerminalLog("  scan, ./reclaim --scan         Run full APFS developer scan", level: .info)
            appState.appendTerminalLog("  rescan, --rescan-fresh         Clear cache and force live recalculation", level: .info)
            appState.appendTerminalLog("  scan docker, --docker          Target Docker virtual machine & cache", level: .info)
            appState.appendTerminalLog("  scan node, --node              Target Node / npm / yarn / pnpm", level: .info)
            appState.appendTerminalLog("  scan xcode, --xcode            Target Xcode DerivedData & Simulators", level: .info)
            appState.appendTerminalLog("  clean, ./reclaim --clean       Safely trash user-selected candidates", level: .info)
            appState.appendTerminalLog("  cache clear                    Purge SQLite directory_cache entries", level: .info)
            appState.appendTerminalLog("  status                         Print current memory & disk index state", level: .info)
            appState.appendTerminalLog("  ls                             List discovered reclaimable targets", level: .info)
            appState.appendTerminalLog("  clear, cls                     Clear terminal console log", level: .info)

        case "clear", "cls":
            appState.clearTerminalLogs()

        case "scan", "./reclaim":
            if tokens.contains("--docker") || tokens.contains("docker") {
                appState.appendTerminalLog("[c++20] Initiating targeted Docker subsystem scan...", level: .info)
                onStartScan(.docker)
            } else if tokens.contains("--node") || tokens.contains("node") {
                appState.appendTerminalLog("[c++20] Initiating targeted Node.js ecosystem scan...", level: .info)
                onStartScan(.node)
            } else if tokens.contains("--xcode") || tokens.contains("xcode") {
                appState.appendTerminalLog("[c++20] Initiating targeted Apple Xcode build artifact scan...", level: .info)
                onStartScan(.xcode)
            } else if tokens.contains("--rescan-fresh") {
                appState.appendTerminalLog("[c++20] Forcing live recalculation; invalidating stale caches...", level: .warning)
                onForceRescan()
            } else {
                appState.appendTerminalLog("[c++20] Starting comprehensive developer waste scan across all vectors...", level: .info)
                onStartScan(nil)
            }

        case "rescan", "--rescan-fresh":
            appState.appendTerminalLog("[c++20] Clearing SQLite directory cache and performing fresh scan...", level: .warning)
            onForceRescan()

        case "clean":
            if appState.selectedBytes > 0 {
                appState.appendTerminalLog("[c++20] Executing safe Trash-first purge of \(appState.formattedSelectedBytes)...", level: .warning)
                onExecuteClean()
            } else {
                appState.appendTerminalLog("[clean:err] No items currently selected. Select items first or use UI checkboxes.", level: .error)
            }

        case "cache":
            if tokens.contains("clear") || tokens.contains("purge") {
                let home = FileManager.default.homeDirectoryForCurrentUser
                let dbPath = home.appendingPathComponent("Library/Application Support/Reclaim/reclaim.db").path
                if let db = try? Database(path: dbPath) {
                    db.clearDirectoryCache()
                    appState.appendTerminalLog("[db:cache] SQLite directory_cache table cleared successfully (0 rows remaining).", level: .success)
                } else {
                    appState.appendTerminalLog("[db:cache] Failed to access local database.", level: .error)
                }
            } else {
                appState.appendTerminalLog("Usage: cache clear", level: .warning)
            }

        case "status":
            let itemsCount = appState.storageItems.count
            let totalBytes = appState.storageItems.reduce(0) { $0 + $1.allocatedSize }
            let totalStr = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            appState.appendTerminalLog("ENGINE STATUS: ONLINE", level: .success)
            appState.appendTerminalLog("  Indexed items: \(itemsCount)", level: .info)
            appState.appendTerminalLog("  Total detected: \(totalStr)", level: .info)
            appState.appendTerminalLog("  Selected: \(appState.formattedSelectedBytes) (\(appState.selectedItemIDs.count) items)", level: .info)
            appState.appendTerminalLog("  Memory mode: Native APFS fts(3) / Zero external daemon overhead", level: .info)

        case "ls":
            if appState.storageItems.isEmpty {
                appState.appendTerminalLog("No items indexed. Run 'scan' first.", level: .warning)
            } else {
                appState.appendTerminalLog(String(format: "%-8s %-12s %s", "RISK", "SIZE", "PATH"), level: .header)
                for item in appState.storageItems.prefix(15) {
                    let sizeStr = ByteCountFormatter.string(fromByteCount: item.allocatedSize, countStyle: .file)
                    appState.appendTerminalLog(String(format: "[%-6s] %-12s %s", item.risk.rawValue.uppercased(), sizeStr, item.path), level: .info)
                }
                if appState.storageItems.count > 15 {
                    appState.appendTerminalLog("... and \(appState.storageItems.count - 15) more items (view in UI above)", level: .info)
                }
            }

        default:
            appState.appendTerminalLog("Unknown command: '\(trimmed)'. Type 'help' for available commands.", level: .error)
        }
    }

    private func color(for level: AppState.TerminalLogLevel) -> Color {
        switch level {
        case .header:
            return Color(red: 1.00, green: 0.84, blue: 0.35) // Gold / C++ comment yellow
        case .command:
            return Color(red: 0.30, green: 0.85, blue: 0.50) // Shell green
        case .info:
            return Color(red: 0.85, green: 0.88, blue: 0.92) // Light terminal gray
        case .success:
            return Color(red: 0.40, green: 0.95, blue: 0.60) // Matrix / Clang OK green
        case .warning:
            return Color(red: 1.00, green: 0.70, blue: 0.20) // Compiler warning amber
        case .error:
            return Color(red: 1.00, green: 0.35, blue: 0.40) // Clang error crimson
        }
    }
}
