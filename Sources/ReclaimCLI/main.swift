// main.swift
// Sources/ReclaimCLI
//
// Fast, native developer command-line interface for Reclaim.
// Designed with a Mole / Homebrew style CLI: ANSI-colored outputs,
// subcommands for scanning, planning, cleaning, memory diagnostics,
// developer macOS defaults, and launch daemon management.

import Foundation
import Reclaim

// MARK: - ANSI Color Helpers

enum ANSI {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"
    static let red = "\u{001B}[31m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let blue = "\u{001B}[34m"
    static let magenta = "\u{001B}[35m"
    static let cyan = "\u{001B}[36m"
}

func printBanner() {
    print("""
\(ANSI.cyan)\(ANSI.bold)⚡ Reclaim\(ANSI.reset) — \(ANSI.dim)Developer Storage & Environment Intelligence for macOS\(ANSI.reset)
""")
}

func printUsage() {
    printBanner()
    print("""
\(ANSI.bold)USAGE:\(ANSI.reset)
  reclaim <subcommand> [options]

\(ANSI.bold)CORE COMMANDS:\(ANSI.reset)
  \(ANSI.green)scan\(ANSI.reset)           Scan developer caches, build artifacts & local AI models
  \(ANSI.green)plan\(ANSI.reset)           Compute safest cleanup plan to free targeted disk space
  \(ANSI.green)clean\(ANSI.reset)          Execute safe Trash-first cleanup with audit receipt
  \(ANSI.green)status\(ANSI.reset)         Display real-time Unified Memory, Swap & Ollama VRAM
  \(ANSI.green)purge-ram\(ANSI.reset)      Discard inactive RAM disk caches via Mach VM eviction

\(ANSI.bold)EXPANDED DEVELOPER UTILITIES:\(ANSI.reset)
  \(ANSI.green)tweaks\(ANSI.reset)         Inspect and toggle developer macOS defaults (hidden files, Dock, etc.)
  \(ANSI.green)daemons\(ANSI.reset)        Manage background LaunchAgents & developer background daemons
  \(ANSI.green)duplicates\(ANSI.reset)     Identify duplicate AI models (.gguf, .safetensors) & ISOs
  \(ANSI.green)maintenance\(ANSI.reset)    Execute system maintenance scripts (DNS flush, Spotlight, APFS)
  \(ANSI.green)help\(ANSI.reset)           Show this help message

\(ANSI.bold)OPTIONS:\(ANSI.reset)
  --target <size>   Target space to free (e.g. 10GB, 500MB) [for plan/clean]
  --dry-run         Simulate cleanup without moving anything to Trash
  --yes, -y         Skip interactive confirmation prompt
""")
}

// MARK: - CLI Application

@main
struct ReclaimCLI {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else {
            printUsage()
            return
        }

        switch command.lowercased() {
        case "scan":
            await handleScan(args: Array(args.dropFirst()))
        case "plan":
            await handlePlan(args: Array(args.dropFirst()))
        case "clean":
            await handleClean(args: Array(args.dropFirst()))
        case "status", "pressure":
            await handleStatus()
        case "purge-ram", "purge_ram":
            await handlePurgeRAM()
        case "tweaks":
            handleTweaks(args: Array(args.dropFirst()))
        case "daemons", "agents":
            handleDaemons(args: Array(args.dropFirst()))
        case "duplicates", "dups":
            await handleDuplicates(args: Array(args.dropFirst()))
        case "maintenance":
            await handleMaintenance(args: Array(args.dropFirst()))
        case "help", "--help", "-h":
            printUsage()
        default:
            print("\(ANSI.red)Error:\(ANSI.reset) Unknown subcommand '\(command)'. Run 'reclaim help' for usage.")
            exit(1)
        }
    }

    // MARK: - Subcommand Handlers

    static func handleScan(args: [String]) async {
        printBanner()
        print("\(ANSI.dim)Scanning developer ecosystems & local AI models... (this may take a few seconds)\(ANSI.reset)")

        let items = await performScan()

        if items.isEmpty {
            print("\(ANSI.yellow)No reclaimable developer artifacts detected.\(ANSI.reset)\n")
            return
        }

        // Group by category
        var categoryMap: [StorageCategory: (count: Int, bytes: Int64)] = [:]
        for item in items {
            let cur = categoryMap[item.category] ?? (count: 0, bytes: 0)
            categoryMap[item.category] = (count: cur.count + 1, bytes: cur.bytes + item.allocatedSize)
        }

        let totalBytes = items.reduce(0) { $0 + $1.allocatedSize }
        let totalStr = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)

        print("\n\(ANSI.bold)DISCOVERED RECLAIMABLE ARTIFACTS:\(ANSI.reset)")
        print(String(repeating: "-", count: 65))
        print(String(format: "%-25@ %-12@ %-15@", "CATEGORY", "ITEMS", "TOTAL SIZE"))
        print(String(repeating: "-", count: 65))

        for (cat, info) in categoryMap.sorted(by: { $0.value.bytes > $1.value.bytes }) {
            let sizeStr = ByteCountFormatter.string(fromByteCount: info.bytes, countStyle: .file)
            print(String(format: "%-25@ %-12d %-15@", cat.displayName, info.count, sizeStr))
        }

        print(String(repeating: "-", count: 65))
        print("\(ANSI.bold)Total Potential Reclaim:\(ANSI.reset) \(ANSI.green)\(ANSI.bold)\(totalStr)\(ANSI.reset) across \(items.count) items.")
        print("\(ANSI.dim)Run 'reclaim plan' or 'reclaim clean --dry-run' to inspect safe candidates.\(ANSI.reset)\n")
    }

    static func handlePlan(args: [String]) async {
        printBanner()
        let targetBytes = parseTargetBytes(from: args) ?? (10 * 1024 * 1024 * 1024) // Default 10GB
        let targetStr = ByteCountFormatter.string(fromByteCount: targetBytes, countStyle: .file)
        print("\(ANSI.dim)Computing optimal plan to free \(targetStr)...\(ANSI.reset)")

        let items = await performScan()
        let engine = RecommendationEngine()
        let plan = engine.createPlan(targetBytes: targetBytes, items: items)

        print("\n\(ANSI.bold)PROPOSED RECLAIM PLAN:\(ANSI.reset)")
        print(String(repeating: "-", count: 75))
        print(String(format: "%-30@ %-12@ %-15@ %-15@", "ITEM", "CATEGORY", "RECLAIMABLE", "RISK"))
        print(String(repeating: "-", count: 75))

        for candidate in plan.candidates.prefix(15) {
            let item = candidate.item
            let name = URL(fileURLWithPath: item.path).lastPathComponent
            let sizeStr = ByteCountFormatter.string(fromByteCount: item.allocatedSize, countStyle: .file)
            let riskStr = item.risk.rawValue.uppercased()
            print(String(format: "%-30@ %-12@ %-15@ %-15@", String(name.prefix(28)), item.category.displayName, sizeStr, riskStr))
        }

        if plan.candidates.count > 15 {
            print("... and \(plan.candidates.count - 15) more candidate items.")
        }

        print(String(repeating: "-", count: 75))
        let planTotalStr = ByteCountFormatter.string(fromByteCount: plan.totalReclaimableBytes, countStyle: .file)
        print("\(ANSI.bold)Plan Yield:\(ANSI.reset) \(ANSI.green)\(planTotalStr)\(ANSI.reset) (Target: \(targetStr))")
        print("\(ANSI.dim)To execute, run: reclaim clean\(ANSI.reset)\n")
    }

    static func handleClean(args: [String]) async {
        printBanner()
        let isDryRun = args.contains("--dry-run")
        let targetBytes = parseTargetBytes(from: args) ?? (10 * 1024 * 1024 * 1024)

        print("\(ANSI.dim)Scanning targets... (dry-run: \(isDryRun))\(ANSI.reset)")
        let items = await performScan()

        let plan = RecommendationEngine().createPlan(targetBytes: targetBytes, items: items)
        guard !plan.candidates.isEmpty else {
            print("\(ANSI.yellow)No eligible cleanup candidates found to free \(ByteCountFormatter.string(fromByteCount: targetBytes, countStyle: .file)).\(ANSI.reset)")
            return
        }

        let totalPlanStr = ByteCountFormatter.string(fromByteCount: plan.totalReclaimableBytes, countStyle: .file)
        print("Identified \(plan.candidates.count) items yielding \(ANSI.bold)\(totalPlanStr)\(ANSI.reset).")

        if isDryRun {
            let report = DryRunReport(plan: plan)
            print("\n\(ANSI.bold)DRY-RUN SIMULATION REPORT:\(ANSI.reset)")
            print(String(repeating: "-", count: 65))
            for item in report.items.prefix(10) {
                print("  • \(item.path) (\(ByteCountFormatter.string(fromByteCount: item.allocatedSize, countStyle: .file))) [Risk: \(item.risk.rawValue)]")
            }
            if report.items.count > 10 {
                print("  ... and \(report.items.count - 10) more items.")
            }
            print(String(repeating: "-", count: 65))
            print("\(ANSI.green)Dry-run completed successfully. Total reclaimable: \(report.formattedReclaimable). No files were touched.\(ANSI.reset)\n")
            return
        }

        // Execution
        let executor = CleanupExecutor(useTrash: true)
        do {
            let receipt = try executor.execute(plan: plan)
            let recoveredStr = ByteCountFormatter.string(fromByteCount: receipt.actualRecoveredBytes, countStyle: .file)
            print("\n\(ANSI.green)\(ANSI.bold)✓ Cleanup Succeeded!\(ANSI.reset)")
            print("Safely moved \(receipt.actions.filter(\.success).count) items to ~/.Trash.")
            print("Recovered: \(ANSI.green)\(ANSI.bold)\(recoveredStr)\(ANSI.reset)")
            print("Audit Receipt ID: \(ANSI.dim)\(receipt.id)\(ANSI.reset)\n")
        } catch {
            print("\(ANSI.red)Cleanup execution failed: \(error.localizedDescription)\(ANSI.reset)")
        }
    }

    static func handleStatus() async {
        printBanner()
        let diagnostics = SystemPressureDiagnostics()
        let report = await diagnostics.generateReport()
        let m = report.metrics

        let activeStr = ByteCountFormatter.string(fromByteCount: m.activeRAM, countStyle: .memory)
        let wiredStr = ByteCountFormatter.string(fromByteCount: m.wiredRAM, countStyle: .memory)

        print("\(ANSI.bold)REAL-TIME MEMORY & SYSTEM PRESSURE:\(ANSI.reset)")
        print(String(repeating: "-", count: 50))
        print("  RAM Total:        \(m.formattedTotalRAM)")
        print("  Memory Pressure:  \(formatPressure(level: report.pressureLevel)) (\(Int(m.pressurePercentage))%)")
        print("  Active Memory:    \(activeStr)")
        print("  Wired Memory:     \(wiredStr)")
        print("  Compressed Memory:\(m.formattedCompressedRAM)")
        print("  Swap Used:        \(m.formattedSwapUsed)")

        let ollama = await diagnostics.inspectLoadedOllamaModels()
        if !ollama.isEmpty {
            print("\n\(ANSI.bold)RESIDENT LOCAL AI (OLLAMA) MODELS IN VRAM:\(ANSI.reset)")
            for model in ollama {
                let sizeStr = ByteCountFormatter.string(fromByteCount: model.sizeVRAM, countStyle: .file)
                print("  • \(ANSI.cyan)\(model.name)\(ANSI.reset) (~ \(sizeStr) VRAM)")
            }
        }
        print(String(repeating: "-", count: 50) + "\n")
    }

    static func handlePurgeRAM() async {
        printBanner()
        print("\(ANSI.dim)Discarding inactive filesystem disk caches via Mach VM eviction...\(ANSI.reset)")
        let engine = SystemMaintenanceEngine()
        let res = await engine.execute(task: .purgeRAM)
        if res.success {
            print("\(ANSI.green)✓ \(res.output)\(ANSI.reset)\n")
        } else {
            print("\(ANSI.red)Failed: \(res.output)\(ANSI.reset)\n")
        }
    }

    static func handleTweaks(args: [String]) {
        printBanner()
        let engine = DeveloperTweaksEngine()
        let tweaks = engine.loadTweaks()

        if let toggleKey = args.first(where: { !$0.starts(with: "-") }) {
            guard let tweak = tweaks.first(where: { $0.id.lowercased() == toggleKey.lowercased() || $0.key.lowercased() == toggleKey.lowercased() }) else {
                print("\(ANSI.red)Error:\(ANSI.reset) Tweak '\(toggleKey)' not found.")
                return
            }
            let newState = !tweak.isEnabled
            engine.setTweak(tweak, enabled: newState)
            print("Tweak \(ANSI.bold)\(tweak.title)\(ANSI.reset) set to: \(newState ? "\(ANSI.green)ENABLED\(ANSI.reset)" : "\(ANSI.yellow)DISABLED\(ANSI.reset)")\n")
            return
        }

        print("\(ANSI.bold)CURATED DEVELOPER macOS TWEAKS:\(ANSI.reset)")
        print(String(repeating: "-", count: 70))
        print(String(format: "%-30@ %-12@ %-25@", "TWEAK ID", "STATUS", "TITLE"))
        print(String(repeating: "-", count: 70))

        for tweak in tweaks {
            let status = tweak.isEnabled ? "\(ANSI.green)ON\(ANSI.reset) " : "\(ANSI.dim)OFF\(ANSI.reset)"
            print(String(format: "%-30@ [%@]  %-25@", tweak.id, status, tweak.title))
        }
        print(String(repeating: "-", count: 70))
        print("\(ANSI.dim)To toggle a tweak: reclaim tweaks <TWEAK_ID>\(ANSI.reset)\n")
    }

    static func handleDaemons(args: [String]) {
        printBanner()
        let manager = LaunchAgentsManager()
        let items = manager.scan()

        if let unloadLabel = args.first(where: { !$0.starts(with: "-") }) {
            guard let item = items.first(where: { $0.label.lowercased() == unloadLabel.lowercased() }) else {
                print("\(ANSI.red)Error:\(ANSI.reset) Service '\(unloadLabel)' not found.")
                return
            }
            let res = manager.setEnabled(item: item, enable: false)
            print(res.message)
            return
        }

        print("\(ANSI.bold)BACKGROUND LAUNCHAGENTS & DAEMONS:\(ANSI.reset)")
        print(String(repeating: "-", count: 75))
        print(String(format: "%-35@ %-10@ %-15@ %-10@", "SERVICE LABEL", "PID", "CATEGORY", "STATUS"))
        print(String(repeating: "-", count: 75))

        for item in items {
            let statusStr = item.isRunning ? "\(ANSI.green)RUNNING\(ANSI.reset)" : "\(ANSI.dim)STOPPED\(ANSI.reset)"
            let pidStr = item.pid != nil ? "\(item.pid!)" : "-"
            let label = String(item.label.prefix(33))
            print(String(format: "%-35@ %-10@ %-15@ %-10@", label, pidStr, item.category.rawValue, statusStr))
        }
        print(String(repeating: "-", count: 75))
        print("\(ANSI.dim)To unload a service: reclaim daemons <SERVICE_LABEL>\(ANSI.reset)\n")
    }

    static func handleDuplicates(args: [String]) async {
        printBanner()
        print("\(ANSI.dim)Scanning for duplicate AI weights (.gguf, .safetensors), disk images & large assets...\(ANSI.reset)")
        let detector = DuplicateAssetDetector()
        let duplicates = await detector.scan { msg in
            print("\(ANSI.dim)\(msg)\(ANSI.reset)")
        }

        if duplicates.isEmpty {
            print("\n\(ANSI.green)✓ No duplicate multi-gigabyte models or assets detected.\(ANSI.reset)\n")
            return
        }

        let totalSavings = duplicates.reduce(0) { $0 + $1.potentialSavings }
        let totalSavingsStr = ByteCountFormatter.string(fromByteCount: totalSavings, countStyle: .file)

        print("\n\(ANSI.bold)DUPLICATE ASSET GROUPS DETECTED:\(ANSI.reset)")
        for (idx, group) in duplicates.enumerated() {
            print("\n\(ANSI.bold)Group \(idx + 1):\(ANSI.reset) Potential Reclaim: \(ANSI.green)\(group.formattedSavings)\(ANSI.reset) (Each copy: \(ByteCountFormatter.string(fromByteCount: group.fileSize, countStyle: .file)))")
            for item in group.items {
                print("  • \(item.path)")
            }
        }
        print("\n\(ANSI.bold)Total Potential Savings:\(ANSI.reset) \(ANSI.green)\(ANSI.bold)\(totalSavingsStr)\(ANSI.reset)\n")
    }

    static func handleMaintenance(args: [String]) async {
        printBanner()
        let engine = SystemMaintenanceEngine()

        if let taskStr = args.first(where: { !$0.starts(with: "-") }),
           let task = MaintenanceTaskID(rawValue: taskStr) {
            print("Executing \(task.title)...")
            let res = await engine.execute(task: task)
            print(res.success ? "\(ANSI.green)✓ \(res.output)\(ANSI.reset)" : "\(ANSI.red)✗ \(res.output)\(ANSI.reset)")
            return
        }

        print("\(ANSI.bold)AVAILABLE SYSTEM MAINTENANCE TASKS:\(ANSI.reset)")
        for task in MaintenanceTaskID.allCases {
            print("  • \(ANSI.green)\(task.rawValue)\(ANSI.reset) — \(task.title)")
        }
        print("\n\(ANSI.dim)Run: reclaim maintenance <task_name>\(ANSI.reset)\n")
    }

    // MARK: - Scan Helper

    private static func performScan() async -> [StorageItem] {
        let container = await DependencyContainer.createWithDefaultAnalyzers()
        let coordinator = ScanCoordinator(analyzerRegistry: container.analyzerRegistry)
        let home = FileManager.default.homeDirectoryForCurrentUser

        let targetRoots = [
            home.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
            home.appendingPathComponent("Library/Developer/Xcode/Archives"),
            home.appendingPathComponent("Library/Developer/CoreSimulator/Caches"),
            home.appendingPathComponent("Library/Containers/com.docker.docker"),
            home.appendingPathComponent(".docker"),
            home.appendingPathComponent(".gradle/caches"),
            home.appendingPathComponent(".npm"),
            home.appendingPathComponent(".yarn/cache"),
            home.appendingPathComponent(".pnpm-store"),
            home.appendingPathComponent(".ollama/models"),
            home.appendingPathComponent(".cache/huggingface"),
            home.appendingPathComponent(".cache/lm_studio"),
            home.appendingPathComponent(".cache/pip"),
            home.appendingPathComponent(".cache/torch"),
            home.appendingPathComponent(".m2/repository"),
            home.appendingPathComponent(".bundle/cache"),
            home.appendingPathComponent("Library/Caches/Homebrew")
        ].filter { FileManager.default.fileExists(atPath: $0.path) }

        let roots = targetRoots.isEmpty ? [home] : targetRoots

        var items: [StorageItem] = []
        for root in roots {
            let context = AnalysisContext(rootURL: root, homeURL: home)
            for await result in coordinator.scanAndAnalyze(rootURL: root, context: context, maxDepth: 4) {
                if result.isCleanupCandidate {
                    items.append(result.item)
                }
            }
        }
        return items
    }

    // MARK: - Helpers

    static func parseTargetBytes(from args: [String]) -> Int64? {
        guard let idx = args.firstIndex(of: "--target"), idx + 1 < args.count else { return nil }
        let raw = args[idx + 1].trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if raw.hasSuffix("GB"), let num = Double(raw.dropLast(2)) {
            return Int64(num * 1024 * 1024 * 1024)
        }
        if raw.hasSuffix("MB"), let num = Double(raw.dropLast(2)) {
            return Int64(num * 1024 * 1024)
        }
        if let bytes = Int64(raw) {
            return bytes
        }
        return nil
    }

    static func formatPressure(level: MemoryPressureLevel) -> String {
        switch level {
        case .normal: return "\(ANSI.green)NORMAL\(ANSI.reset)"
        case .warning: return "\(ANSI.yellow)WARNING\(ANSI.reset)"
        case .critical: return "\(ANSI.red)CRITICAL\(ANSI.reset)"
        }
    }
}
