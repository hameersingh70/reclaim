// MaintenanceView.swift
// ReclaimUI/Views
//
// Native macOS System Maintenance & Performance Optimization Suite (CleanMyMac & OnyX style).
// Features:
// - Flush DNS Cache (resolves local dev network issues & mDNS)
// - Reclaim APFS Purgeable Space (thins Time Machine local snapshots)
// - Purge Inactive RAM (frees physical memory without restarting)
// - Rebuild LaunchServices Database (fixes 'Open With' duplicates)
// - Reindex Spotlight Search (rebuilds corrupted metadata index)

import SwiftUI
import AppKit
import Reclaim

public struct MaintenanceView: View {
    @ObservedObject public var appState: AppState
    public let theme: any Theme

    @State private var runningTasks: Set<MaintenanceTaskID> = []
    @State private var taskResults: [MaintenanceTaskID: MaintenanceTaskResult] = [:]
    @State private var isRunningAll: Bool = false

    private let engine = SystemMaintenanceEngine()

    public init(appState: AppState, theme: any Theme) {
        self.appState = appState
        self.theme = theme
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard

                runAllCard

                tasksList
            }
            .padding(24)
        }
        .background(theme.windowBackground)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 44, height: 44)
                .background(Color(red: 0.35, green: 0.75, blue: 1.0)) // Blue
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 2))
                .shadow(color: .black, radius: 0, x: 2, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text("macOS System Maintenance")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                Text("Essential macOS maintenance scripts to optimize performance and clear system bloat.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.65))
            }

            Spacer()
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
        .shadow(color: .black, radius: 0, x: 3, y: 3)
    }

    // MARK: - Run All Card

    private var runAllCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("RECOMMENDED OPTIMIZATION")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                    .foregroundColor(.black)
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1.2))

                Text("Execute Full System Maintenance")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                Text("Sequentially flushes DNS, reclaims APFS purgeable snapshot blocks, and purges RAM.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.65))
            }

            Spacer()

            Button(action: { runAllTasks() }) {
                HStack(spacing: 6) {
                    if isRunningAll {
                        ProgressView().controlSize(.small)
                        Text("RUNNING TASKS...")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11))
                        Text("RUN ALL SCRIPTS")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 1.00, green: 0.40, blue: 0.42))
                .foregroundColor(.black)
                .cornerRadius(7)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black, lineWidth: 2))
                .shadow(color: .black, radius: 0, x: 2.5, y: 2.5)
            }
            .buttonStyle(.plain)
            .disabled(isRunningAll || !runningTasks.isEmpty)
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
        .shadow(color: .black, radius: 0, x: 3, y: 3)
    }

    // MARK: - Tasks List

    private var tasksList: some View {
        VStack(spacing: 10) {
            ForEach(MaintenanceTaskID.allCases) { task in
                let isRunning = runningTasks.contains(task)
                let result = taskResults[task]

                HStack(spacing: 14) {
                    Image(systemName: task.iconName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 34, height: 34)
                        .background(taskColor(for: task))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.black)

                        Text(task.subtitle)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Color.black.opacity(0.65))

                        if let res = result {
                            HStack(spacing: 6) {
                                Image(systemName: res.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundColor(res.success ? Color(red: 0.1, green: 0.6, blue: 0.2) : Color.red)
                                    .font(.system(size: 11))
                                Text(res.output)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(Color.black.opacity(0.7))
                                    .lineLimit(1)
                            }
                            .padding(.top, 2)
                        }
                    }

                    Spacer()

                    Button {
                        executeSingleTask(task)
                    } label: {
                        HStack(spacing: 4) {
                            if isRunning {
                                ProgressView().controlSize(.small)
                            }
                            Text(isRunning ? "RUNNING..." : "EXECUTE")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isRunning ? Color.black.opacity(0.08) : Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                        .shadow(color: isRunning ? .clear : .black, radius: 0, x: 1.5, y: 1.5)
                    }
                    .buttonStyle(.plain)
                    .disabled(isRunning)
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 1.8))
                .shadow(color: .black, radius: 0, x: 2.5, y: 2.5)
            }
        }
    }

    private func taskColor(for task: MaintenanceTaskID) -> Color {
        switch task {
        case .flushDNS: return Color(red: 0.35, green: 0.75, blue: 1.0)
        case .thinSnapshots: return Color(red: 0.32, green: 0.81, blue: 0.40)
        case .purgeRAM: return Color(red: 1.00, green: 0.72, blue: 0.18)
        case .rebuildLaunchServices: return Color(red: 0.80, green: 0.36, blue: 0.91)
        case .reindexSpotlight: return Color(red: 1.00, green: 0.40, blue: 0.42)
        case .repairDiskPermissions: return Color(red: 0.35, green: 0.85, blue: 0.85)
        case .clearQuickLookCache: return Color(red: 1.00, green: 0.85, blue: 0.30)
        case .clearFontCache: return Color(red: 0.85, green: 0.65, blue: 0.45)
        case .speedUpMail: return Color(red: 0.55, green: 0.60, blue: 0.95)
        }
    }

    // MARK: - Execution

    private func executeSingleTask(_ task: MaintenanceTaskID) {
        runningTasks.insert(task)
        appState.appendTerminalLog("[maintenance:start] Executing \(task.title)...", level: .command)

        Task {
            let res = await engine.execute(task: task)
            await MainActor.run {
                runningTasks.remove(task)
                taskResults[task] = res
                let timeStr = String(format: "%.2fs", res.executionTime)
                if res.success {
                    appState.appendTerminalLog("[maintenance:ok] \(task.title) complete (\(timeStr)): \(res.output)", level: .success)
                } else {
                    appState.appendTerminalLog("[maintenance:err] \(task.title) error: \(res.output)", level: .error)
                }
                appState.notifyCleanupPerformed()
            }
        }
    }

    private func runAllTasks() {
        isRunningAll = true
        appState.appendTerminalLog("[maintenance:batch] Starting full system maintenance pipeline...", level: .header)

        Task {
            let all = [MaintenanceTaskID.flushDNS, .thinSnapshots, .purgeRAM, .rebuildLaunchServices]
            for task in all {
                _ = await MainActor.run { runningTasks.insert(task) }
                let res = await engine.execute(task: task)
                await MainActor.run {
                    runningTasks.remove(task)
                    taskResults[task] = res
                    let timeStr = String(format: "%.2fs", res.executionTime)
                    appState.appendTerminalLog("[maintenance:ok] \(task.title) finished (\(timeStr)).", level: .info)
                }
            }
            await MainActor.run {
                isRunningAll = false
                appState.appendTerminalLog("[maintenance:complete] All maintenance tasks completed.", level: .success)
                appState.notifyCleanupPerformed()
            }
        }
    }
}
