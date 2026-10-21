// SystemStorageView.swift
// ReclaimUI/Views
//
// Native Apple Storage Manager view for Reclaim in Retro Pop Tech / Neo-Brutalist aesthetic.
// Features:
// - Exact live volume breakdown (Applications, Bin, Developer, Documents, macOS, System Data, Other Users)
// - Stacked multi-color segmented storage allocation bar
// - Direct folder revelation in Finder
// - Interactive drill-down inspector sheet with sub-items
// - One-click targeted actions (Empty Bin, Purge Developer Caches, Flush System Caches)

import SwiftUI
import AppKit
import Reclaim

struct SystemStorageView: View {
    @ObservedObject var appState: AppState
    let theme: any Theme
    let onNavigateToSection: (NavigationSection) -> Void
    let onTriggerCategoryScan: ((StorageCategory?) -> Void)?

    @State private var overview: SystemStorageOverview = .empty
    @State private var isLoading: Bool = true
    @State private var selectedCategory: SystemStorageCategoryAllocation? = nil
    @State private var actionFeedbackMessage: String? = nil
    @State private var isPerformingAction: Bool = false
    @State private var runningAppCachesDetected: [RunningAppCacheInfo] = []
    @State private var closedAppCachesDetected: [RunningAppCacheInfo] = []
    @State private var showFlushCachePromptSheet: Bool = false

    private let inspector = SystemStorageInspector()

    init(
        appState: AppState,
        theme: any Theme,
        onNavigateToSection: @escaping (NavigationSection) -> Void,
        onTriggerCategoryScan: ((StorageCategory?) -> Void)? = nil
    ) {
        self.appState = appState
        self.theme = theme
        self.onNavigateToSection = onNavigateToSection
        self.onTriggerCategoryScan = onTriggerCategoryScan
        let initial = inspector.getInitialOverview()
        self._overview = State(initialValue: initial)
        self._isLoading = State(initialValue: false)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView

                if isLoading && overview.totalCapacityBytes == 0 {
                    loadingBanner
                } else {
                    storageBarCard
                    recommendationsCard
                    categoriesBreakdownList
                }
            }
            .padding(24)
        }
        .background(theme.windowBackground)
        .onAppear {
            loadStorageMetrics()
        }
        .onChange(of: appState.storageMetricsRevision) { _ in
            loadStorageMetrics(force: false)
        }
        .onReceive(Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()) { _ in
            pollLiveDiskCapacity()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            pollLiveDiskCapacity()
        }
        .sheet(item: $selectedCategory) { category in
            CategoryDetailSheet(
                category: category,
                theme: theme,
                onEmptyBin: {
                    emptyBinAction()
                },
                onDeleteTrashItem: { path in
                    deleteTrashItemAction(path: path)
                },
                onTriggerDevScan: {
                    selectedCategory = nil
                    onNavigateToSection(.smartScan)
                    onTriggerCategoryScan?(nil)
                },
                onCleanCaches: {
                    cleanCachesAction()
                },
                onRevealPath: { path in
                    revealInFinder(path: path)
                }
            )
        }
        .sheet(isPresented: $showFlushCachePromptSheet) {
            FlushCachePromptSheet(
                runningApps: runningAppCachesDetected,
                closedApps: closedAppCachesDetected,
                theme: theme,
                onFlushClosedOnly: {
                    showFlushCachePromptSheet = false
                    executeFlushCaches(includeRunning: false)
                },
                onFlushAll: {
                    showFlushCachePromptSheet = false
                    executeFlushCaches(includeRunning: true)
                },
                onCancel: {
                    showFlushCachePromptSheet = false
                }
            )
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("APPLE STORAGE MANAGER")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                        .foregroundColor(.black)
                        .cornerRadius(5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.5))

                    Text("APFS VOLUME")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1.2))
                }

                Text("macOS System Storage")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.black)

                Text("Volume allocation breakdown across Applications, Developer, Bin, macOS and System Data.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.65))
            }

            Spacer()

            Button(action: {
                loadStorageMetrics()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isLoading ? "hourglass" : "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                    Text(isLoading ? "SCANNING..." : "REFRESH STORAGE")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                .shadow(color: .black, radius: 0, x: 2.5, y: 2.5)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
    }

    // MARK: - Loading Banner

    private var loadingBanner: some View {
        HStack(spacing: 14) {
            ProgressView()
                .controlSize(.regular)

            VStack(alignment: .leading, spacing: 2) {
                Text("Analyzing APFS volume & directory allocations...")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                Text("Enumerating Applications, Developer toolchains, Trash and System Data")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.6))
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 2))
        .shadow(color: .black, radius: 0, x: 3, y: 3)
    }

    // MARK: - Storage Bar Overview Card

    private var storageBarCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Volume Header Row
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.black)
                    Text(overview.volumeName)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                }

                Spacer()

                HStack(spacing: 10) {
                    Text("\(overview.formattedUsed) used of \(overview.formattedTotal)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.black.opacity(0.8))

                    Text("\(overview.formattedAvailable) Available")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.32, green: 0.81, blue: 0.40)) // Mint Green
                        .foregroundColor(.black)
                        .cornerRadius(5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.5))
                }
            }

            // Multi-segment Storage Bar
            GeometryReader { geo in
                let width = geo.size.width
                let total = max(1, overview.totalCapacityBytes)

                HStack(spacing: 0) {
                    ForEach(overview.categories) { cat in
                        let catWidth = max(2, CGFloat(Double(cat.allocatedBytes) / Double(total)) * width)
                        Rectangle()
                            .fill(colorForHex(cat.badgeColorHex))
                            .frame(width: catWidth)
                    }

                    // Available / Free space segment
                    let availWidth = max(0, CGFloat(Double(overview.availableCapacityBytes) / Double(total)) * width)
                    Rectangle()
                        .fill(Color(red: 0.94, green: 0.92, blue: 0.88))
                        .frame(width: availWidth)
                }
            }
            .frame(height: 28)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
            .shadow(color: .black, radius: 0, x: 3, y: 3)

            // Segment Legend
            WrappingLegendView(
                categories: overview.categories,
                availableBytes: overview.availableCapacityBytes,
                onSelectCategory: { cat in
                    selectedCategory = cat
                }
            )
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
        .shadow(color: .black, radius: 0, x: 3, y: 3)
    }

    // MARK: - Recommendations Card

    private var recommendationsCard: some View {
        let binCat = overview.categories.first { $0.categoryType == .bin }
        let devCat = overview.categories.first { $0.categoryType == .developer }

        return VStack(alignment: .leading, spacing: 12) {
            Text("RECOMMENDATIONS")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                .foregroundColor(.black)
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1.2))

            VStack(spacing: 10) {
                // Empty Bin Recommendation
                RecommendationRow(
                    icon: "trash.fill",
                    iconColor: Color(red: 1.00, green: 0.82, blue: 0.22),
                    title: "Empty Bin",
                    subtitle: "Save space by permanently erasing items discarded in Trash (\(binCat?.formattedBytes ?? "0 KB")).",
                    actionTitle: (binCat?.allocatedBytes ?? 0) > 0 ? "Empty Bin Now" : "Bin is Clean",
                    actionDisabled: (binCat?.allocatedBytes ?? 0) == 0 || isPerformingAction,
                    action: {
                        emptyBinAction()
                    }
                )

                Divider().background(Color.black.opacity(0.15))

                // Purge Developer Caches
                RecommendationRow(
                    icon: "hammer.fill",
                    iconColor: Color(red: 0.32, green: 0.81, blue: 0.40),
                    title: "Purge Developer Caches",
                    subtitle: "Reclaim up to \(devCat?.formattedBytes ?? "0 KB") in Xcode DerivedData, Docker build layers, Ollama & node_modules.",
                    actionTitle: "Deep Developer Scan",
                    actionDisabled: isPerformingAction,
                    action: {
                        onNavigateToSection(.smartScan)
                        onTriggerCategoryScan?(nil)
                    }
                )

                Divider().background(Color.black.opacity(0.15))

                // Clean System & User Caches
                RecommendationRow(
                    icon: "bolt.shield.fill",
                    iconColor: Color(red: 0.20, green: 0.60, blue: 0.94),
                    title: "Clean Temporary Caches",
                    subtitle: "Safely flush non-essential application caches and logs in ~/Library/Caches.",
                    actionTitle: "Flush User Caches",
                    actionDisabled: isPerformingAction,
                    action: {
                        cleanCachesAction()
                    }
                )
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
        .shadow(color: .black, radius: 0, x: 3, y: 3)
    }

    // MARK: - Categories Breakdown List

    private var categoriesBreakdownList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ALL STORAGE ALLOCATIONS")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.black)

                Spacer()

                if let msg = actionFeedbackMessage {
                    Text(msg)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.1, green: 0.6, blue: 0.2))
                        .transition(.opacity)
                }
            }

            VStack(spacing: 8) {
                ForEach(overview.categories) { category in
                    StorageCategoryRow(
                        category: category,
                        theme: theme,
                        onOpenInfo: {
                            selectedCategory = category
                        },
                        onOpenFolder: {
                            if category.categoryType == .systemData {
                                let libPath = ("~/Library" as NSString).expandingTildeInPath
                                revealInFinder(path: libPath)
                            } else if let first = category.contributingPaths.first {
                                revealInFinder(path: first)
                            }
                        },
                        onAnalyze: {
                            handleCategoryAnalyze(category: category)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func handleCategoryAnalyze(category: SystemStorageCategoryAllocation) {
        switch category.categoryType {
        case .developer:
            onNavigateToSection(.smartScan)
            onTriggerCategoryScan?(nil)
        case .bin:
            selectedCategory = category
        case .applications:
            onNavigateToSection(.uninstaller)
        case .documentsAndDownloads:
            onNavigateToSection(.largeFiles)
        case .systemData:
            cleanCachesAction()
        case .macOS, .otherUsersAndShared, .mailAndMedia:
            selectedCategory = category
        }
    }

    private func loadStorageMetrics(force: Bool = false) {
        if overview.categories.isEmpty || force {
            isLoading = true
        }
        Task {
            let res = await inspector.inspectOverview(scannedItems: appState.storageItems)
            await MainActor.run {
                self.overview = res
                self.isLoading = false
            }
        }
    }

    private func pollLiveDiskCapacity() {
        let (volName, totalCap, availCap, usedCap) = inspector.getVolumeMetrics()
        guard totalCap > 0 else { return }
        if availCap != overview.availableCapacityBytes || usedCap != overview.usedCapacityBytes {
            overview.availableCapacityBytes = availCap
            overview.usedCapacityBytes = usedCap
            overview.totalCapacityBytes = totalCap
            overview.volumeName = volName
            loadStorageMetrics(force: false)
        }
    }

    private func emptyBinAction() {
        isPerformingAction = true
        Task {
            do {
                let reclaimed = try inspector.emptyTrash()
                await MainActor.run {
                    self.actionFeedbackMessage = "✓ Emptied Bin (Reclaimed \(ByteCountFormatter.string(fromByteCount: reclaimed, countStyle: .file)))"
                    self.isPerformingAction = false
                    self.appState.notifyCleanupPerformed()
                    self.loadStorageMetrics()
                }
            } catch {
                await MainActor.run {
                    self.actionFeedbackMessage = "Error emptying bin: \(error.localizedDescription)"
                    self.isPerformingAction = false
                }
            }
        }
    }

    private func deleteTrashItemAction(path: String) {
        Task {
            do {
                try inspector.deleteTrashItem(path: path)
                await MainActor.run {
                    self.appState.notifyCleanupPerformed()
                    self.loadStorageMetrics()
                    // Refresh selected category if open
                    if let sel = self.selectedCategory, sel.categoryType == .bin {
                        self.selectedCategory?.subItems.removeAll { $0.path == path }
                    }
                }
            } catch {
                await MainActor.run {
                    self.actionFeedbackMessage = "Could not delete item: \(error.localizedDescription)"
                }
            }
        }
    }

    private func cleanCachesAction() {
        isPerformingAction = true
        Task {
            let (runningCaches, closedCaches) = inspector.inspectApplicationCaches()
            await MainActor.run {
                self.isPerformingAction = false
                if runningCaches.isEmpty {
                    // No running application caches detected: flush closed apps directly
                    executeFlushCaches(includeRunning: false)
                } else {
                    // Running applications with active caches detected!
                    // Prompt user: flush closed apps only vs include running apps vs cancel
                    self.runningAppCachesDetected = runningCaches
                    self.closedAppCachesDetected = closedCaches
                    self.showFlushCachePromptSheet = true
                }
            }
        }
    }

    private func executeFlushCaches(includeRunning: Bool) {
        isPerformingAction = true
        Task {
            do {
                let result = try inspector.cleanUserCachesWithDetails(includeRunningApps: includeRunning)
                await MainActor.run {
                    self.isPerformingAction = false
                    if includeRunning {
                        self.actionFeedbackMessage = "✓ Flushed all caches (\(ByteCountFormatter.string(fromByteCount: result.reclaimedBytes, countStyle: .file)))"
                    } else if !result.skippedRunningApps.isEmpty {
                        self.actionFeedbackMessage = "✓ Flushed closed app caches (\(ByteCountFormatter.string(fromByteCount: result.reclaimedBytes, countStyle: .file))) — Preserved \(result.skippedRunningApps.count) running apps"
                    } else {
                        self.actionFeedbackMessage = "✓ Flushed closed app caches (\(ByteCountFormatter.string(fromByteCount: result.reclaimedBytes, countStyle: .file)))"
                    }
                    self.appState.notifyCleanupPerformed()
                    self.loadStorageMetrics()
                }
            } catch {
                await MainActor.run {
                    self.actionFeedbackMessage = "Cache flush error: \(error.localizedDescription)"
                    self.isPerformingAction = false
                }
            }
        }
    }

    private func revealInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        if !FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open(url.deletingLastPathComponent())
        }
    }

    private func colorForHex(_ hex: String) -> Color {
        switch hex {
        case "#FF6B6B": return Color(red: 1.00, green: 0.40, blue: 0.42) // Coral
        case "#FFD43B": return Color(red: 1.00, green: 0.82, blue: 0.22) // Yellow
        case "#51CF66": return Color(red: 0.32, green: 0.81, blue: 0.40) // Mint Green
        case "#339AF0": return Color(red: 0.20, green: 0.60, blue: 0.94) // Blue
        case "#FFA94D": return Color(red: 1.00, green: 0.65, blue: 0.30) // Orange
        case "#CC5DE8": return Color(red: 0.80, green: 0.36, blue: 0.91) // Purple
        case "#868E96": return Color(red: 0.52, green: 0.56, blue: 0.59) // Slate
        default: return Color(red: 0.35, green: 0.75, blue: 1.0)
        }
    }
}

// MARK: - Recommendation Row

private struct RecommendationRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let actionTitle: String
    var actionDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 34, height: 34)
                .background(iconColor)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.65))
            }

            Spacer()

            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(actionDisabled ? Color.black.opacity(0.08) : Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                    .shadow(color: actionDisabled ? .clear : .black, radius: 0, x: 2, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(actionDisabled)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Storage Category Row

private struct StorageCategoryRow: View {
    let category: SystemStorageCategoryAllocation
    let theme: any Theme
    let onOpenInfo: () -> Void
    let onOpenFolder: () -> Void
    let onAnalyze: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Category Icon Badge
            Image(systemName: category.iconName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 30, height: 30)
                .background(badgeColor)
                .cornerRadius(7)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black, lineWidth: 1.5))

            // Category Details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(category.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.black)

                    if category.categoryType == .systemData {
                        Text("VM Swap, App Support, Caches & APFS Snapshots")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.black.opacity(0.45))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else if let first = category.contributingPaths.first {
                        Text(first)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.black.opacity(0.45))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Text(category.cleanupActionDescription)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            // Allocation Size Badge
            Text(category.formattedBytes)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(badgeColor.opacity(0.25))
                .foregroundColor(.black)
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))

            // Action: Open Folder
            Button(action: onOpenFolder) {
                Image(systemName: "folder")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 26, height: 26)
                    .background(Color.white)
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                    .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
            }
            .buttonStyle(.plain)
            .help("Reveal folder in Finder")

            // Action: Free Up / Analyze
            if category.isCleanable || category.categoryType == .developer {
                Button(action: onAnalyze) {
                    Text(analyzeButtonText)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                        .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                }
                .buttonStyle(.plain)
            }

            // Action: (i) Info Drill-Down Button
            Button(action: onOpenInfo) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 26, height: 26)
                    .background(Color.white)
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                    .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
            }
            .buttonStyle(.plain)
            .help("Inspect contributing items & sub-breakdown")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
        .shadow(color: .black, radius: 0, x: 2.5, y: 2.5)
    }

    private var analyzeButtonText: String {
        switch category.categoryType {
        case .developer: return "ANALYZE"
        case .bin: return "EMPTY"
        case .applications: return "UNINSTALL"
        case .documentsAndDownloads: return "REVIEW"
        case .systemData: return "CLEAN"
        default: return "INSPECT"
        }
    }

    private var badgeColor: Color {
        switch category.badgeColorHex {
        case "#FF6B6B": return Color(red: 1.00, green: 0.40, blue: 0.42)
        case "#FFD43B": return Color(red: 1.00, green: 0.82, blue: 0.22)
        case "#51CF66": return Color(red: 0.32, green: 0.81, blue: 0.40)
        case "#339AF0": return Color(red: 0.20, green: 0.60, blue: 0.94)
        case "#FFA94D": return Color(red: 1.00, green: 0.65, blue: 0.30)
        case "#CC5DE8": return Color(red: 0.80, green: 0.36, blue: 0.91)
        case "#868E96": return Color(red: 0.52, green: 0.56, blue: 0.59)
        default: return Color(red: 0.35, green: 0.75, blue: 1.0)
        }
    }
}

// MARK: - Wrapping Legend View

private struct WrappingLegendView: View {
    let categories: [SystemStorageCategoryAllocation]
    let availableBytes: Int64
    let onSelectCategory: (SystemStorageCategoryAllocation) -> Void

    var body: some View {
        FlowLayout(spacing: 12) {
            ForEach(categories) { cat in
                Button(action: { onSelectCategory(cat) }) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(colorForHex(cat.badgeColorHex))
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.black, lineWidth: 1))

                        Text("\(cat.name):")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.black)

                        Text(cat.formattedBytes)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.black.opacity(0.75))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white)
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            // Available Space Legend
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(red: 0.94, green: 0.92, blue: 0.88))
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.black, lineWidth: 1))

                Text("Available:")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.black)

                Text(ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.black.opacity(0.75))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white)
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1))
        }
    }

    private func colorForHex(_ hex: String) -> Color {
        switch hex {
        case "#FF6B6B": return Color(red: 1.00, green: 0.40, blue: 0.42)
        case "#FFD43B": return Color(red: 1.00, green: 0.82, blue: 0.22)
        case "#51CF66": return Color(red: 0.32, green: 0.81, blue: 0.40)
        case "#339AF0": return Color(red: 0.20, green: 0.60, blue: 0.94)
        case "#FFA94D": return Color(red: 1.00, green: 0.65, blue: 0.30)
        case "#CC5DE8": return Color(red: 0.80, green: 0.36, blue: 0.91)
        case "#868E96": return Color(red: 0.52, green: 0.56, blue: 0.59)
        default: return Color(red: 0.35, green: 0.75, blue: 1.0)
        }
    }
}

// MARK: - Category Detail Sheet (Modal Drill-Down)

private struct CategoryDetailSheet: View {
    let category: SystemStorageCategoryAllocation
    let theme: any Theme
    let onEmptyBin: () -> Void
    let onDeleteTrashItem: (String) -> Void
    let onTriggerDevScan: () -> Void
    let onCleanCaches: () -> Void
    let onRevealPath: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Sheet Header
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: category.iconName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 32, height: 32)
                        .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                        Text(category.formattedBytes)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.black.opacity(0.6))
                    }
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

            // Contributing Paths info
            VStack(alignment: .leading, spacing: 6) {
                Text("CONTRIBUTING FILESYSTEM LOCATIONS")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(.black)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(category.contributingPaths, id: \.self) { p in
                        HStack(spacing: 6) {
                            Text("•")
                            Text(p)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("Reveal") {
                                onRevealPath(p)
                            }
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .buttonStyle(.plain)
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.98, green: 0.96, blue: 0.93))

            // Sub-Items List
            ScrollView {
                VStack(spacing: 8) {
                    if category.subItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color(red: 0.22, green: 0.78, blue: 0.52))
                            Text("No large items detected or folder is empty.")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                        }
                        .padding(40)
                    } else {
                        ForEach(category.subItems) { item in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.black)
                                        .lineLimit(1)

                                    if !item.subtitle.isEmpty {
                                        Text(item.subtitle)
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundColor(Color.black.opacity(0.55))
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Text(item.formattedBytes)
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                                    .foregroundColor(.black)
                                    .cornerRadius(4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1))

                                Button("Reveal") {
                                    onRevealPath(item.path)
                                }
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1))
                                .buttonStyle(.plain)

                                if category.categoryType == .bin {
                                    Button("Delete") {
                                        onDeleteTrashItem(item.path)
                                    }
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color(red: 1.00, green: 0.40, blue: 0.42))
                                    .foregroundColor(.black)
                                    .cornerRadius(4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1))
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.2))
                            .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                        }
                    }
                }
                .padding(14)
            }

            // Sheet Footer Actions
            HStack {
                Spacer()

                if category.categoryType == .bin && category.allocatedBytes > 0 {
                    Button(action: {
                        dismiss()
                        onEmptyBin()
                    }) {
                        Text("EMPTY ENTIRE BIN NOW")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(red: 1.00, green: 0.40, blue: 0.42))
                            .foregroundColor(.black)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                            .shadow(color: .black, radius: 0, x: 2, y: 2)
                    }
                    .buttonStyle(.plain)
                } else if category.categoryType == .developer {
                    Button(action: {
                        dismiss()
                        onTriggerDevScan()
                    }) {
                        Text("RUN RECLAIM DEVELOPER SCAN")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.32, green: 0.81, blue: 0.40))
                            .foregroundColor(.black)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                            .shadow(color: .black, radius: 0, x: 2, y: 2)
                    }
                } else if category.categoryType == .systemData {
                    Button(action: {
                        dismiss()
                        onCleanCaches()
                    }) {
                        Text("FLUSH TEMPORARY APP CACHES")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.20, green: 0.60, blue: 0.94))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                            .shadow(color: .black, radius: 0, x: 2, y: 2)
                    }
                    .buttonStyle(.plain)
                }

                Button("Close") {
                    dismiss()
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                .shadow(color: .black, radius: 0, x: 2, y: 2)
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color.white)
            .overlay(Rectangle().frame(height: 1.5).foregroundColor(.black), alignment: .top)
        }
        .frame(minWidth: 540, minHeight: 460)
        .background(Color(red: 0.98, green: 0.96, blue: 0.93))
    }
}

// MARK: - FlowLayout helper for Wrapping Legend

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeightInRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += maxHeightInRow + spacing
                maxHeightInRow = 0
            }
            x += size.width + spacing
            maxHeightInRow = max(maxHeightInRow, size.height)
            height = max(height, y + maxHeightInRow)
        }

        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var maxHeightInRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += maxHeightInRow + spacing
                maxHeightInRow = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            maxHeightInRow = max(maxHeightInRow, size.height)
        }
    }
}

// MARK: - Flush Cache Prompt Sheet (Safe Running App Cache Choice)

private struct FlushCachePromptSheet: View {
    let runningApps: [RunningAppCacheInfo]
    let closedApps: [RunningAppCacheInfo]
    let theme: any Theme
    let onFlushClosedOnly: () -> Void
    let onFlushAll: () -> Void
    let onCancel: () -> Void

    private var closedTotalBytes: Int64 {
        closedApps.reduce(0) { $0 + $1.allocatedBytes }
    }

    private var runningTotalBytes: Int64 {
        runningApps.reduce(0) { $0 + $1.allocatedBytes }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.black)
                    .frame(width: 34, height: 34)
                    .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                    .cornerRadius(7)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black, lineWidth: 1.5))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("CACHE FLUSH SAFETY CHECK")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 1.00, green: 0.72, blue: 0.18).opacity(0.35))
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1))

                        Text("\(runningApps.count) RUNNING APPS")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.90, green: 0.20, blue: 0.20))
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1))
                    }

                    Text("Active Applications Detected")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                }

                Spacer()

                Button(action: onCancel) {
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
            .padding(18)
            .background(Color.white)
            .overlay(Rectangle().frame(height: 1.5).foregroundColor(.black), alignment: .bottom)

            // Warning Notice
            VStack(alignment: .leading, spacing: 6) {
                Text("SAFETY WARNING: RUNNING PROCESSES")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.black)

                Text("Flushing caches for actively open applications may invalidate web sessions, force open tabs to reload, or cause process slowdowns. By default, Reclaim ignores running applications and only flushes closed apps.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 1.00, green: 0.96, blue: 0.88))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color.black.opacity(0.15)), alignment: .bottom)

            // Scrollable Running Apps List
            ScrollView {
                VStack(spacing: 12) {
                    // Running Apps Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("RUNNING APPLICATIONS (ACTIVE CACHES)")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: runningTotalBytes, countStyle: .file))
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(Color(red: 0.85, green: 0.15, blue: 0.15))
                        }

                        ForEach(runningApps) { app in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(red: 0.22, green: 0.78, blue: 0.40))
                                    .frame(width: 8, height: 8)
                                    .overlay(Circle().stroke(Color.black, lineWidth: 1))

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(app.appName)
                                            .font(.system(size: 12, weight: .black, design: .rounded))
                                            .foregroundColor(.black)

                                        Text("RUNNING")
                                            .font(.system(size: 9, weight: .black, design: .monospaced))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Color(red: 0.22, green: 0.78, blue: 0.40).opacity(0.25))
                                            .foregroundColor(.black)
                                            .cornerRadius(3)
                                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black, lineWidth: 1))
                                    }

                                    Text(app.cacheFolderPath)
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundColor(Color.black.opacity(0.5))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }

                                Spacer()

                                Text(app.formattedBytes)
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.white)
                                    .foregroundColor(.black)
                                    .cornerRadius(4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.2))
                            .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                        }
                    }

                    // Closed Apps Summary Card
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.15, green: 0.65, blue: 0.35))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Closed Application Caches (Safe to Wipe)")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(.black)

                            Text("\(closedApps.count) closed apps & stale caches • Total: \(ByteCountFormatter.string(fromByteCount: closedTotalBytes, countStyle: .file))")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(Color.black.opacity(0.65))
                        }

                        Spacer()

                        Text("SAFE")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.32, green: 0.81, blue: 0.40))
                            .foregroundColor(.black)
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1))
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
                }
                .padding(16)
            }

            // Footer Actions
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    // Safe Recommended Action: Flush Closed Apps Only
                    Button(action: onFlushClosedOnly) {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 12, weight: .bold))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("FLUSH CLOSED APPS ONLY (SAFE)")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                Text("Ignores running apps • Reclaims \(ByteCountFormatter.string(fromByteCount: closedTotalBytes, countStyle: .file))")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .opacity(0.8)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(Color(red: 0.32, green: 0.81, blue: 0.40))
                        .foregroundColor(.black)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                        .shadow(color: .black, radius: 0, x: 2, y: 2)
                    }
                    .buttonStyle(.plain)

                    // Aggressive Action: Flush All Including Running Apps
                    Button(action: onFlushAll) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("FLUSH ALL (INC. RUNNING)")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                Text("Wipes all • Reclaims \(ByteCountFormatter.string(fromByteCount: closedTotalBytes + runningTotalBytes, countStyle: .file))")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .opacity(0.8)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color(red: 1.00, green: 0.40, blue: 0.42))
                        .foregroundColor(.black)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                        .shadow(color: .black, radius: 0, x: 2, y: 2)
                    }
                    .buttonStyle(.plain)

                    // Cancel
                    Button("Cancel", action: onCancel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                        .shadow(color: .black, radius: 0, x: 2, y: 2)
                        .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(Color.white)
            .overlay(Rectangle().frame(height: 1.5).foregroundColor(.black), alignment: .top)
        }
        .frame(minWidth: 560, minHeight: 480)
        .background(Color(red: 0.98, green: 0.96, blue: 0.93))
    }
}
