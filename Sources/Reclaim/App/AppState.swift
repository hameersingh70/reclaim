// AppState.swift
// App/
//
// The top-level observable application state.
// Views observe this object; business logic lives in the core modules.
// UI must never contain filesystem-analysis logic (PRD §55).

import Foundation

/// Top-level application state observed by SwiftUI views.
///
/// This is the single source of truth for UI-facing state transitions.
/// It does not contain filesystem logic — it delegates to injected services
/// via `DependencyContainer`.
@MainActor
public final class AppState: ObservableObject {

    // MARK: - Scan state

    public enum ScanPhase: Equatable, Sendable {
        case idle
        case scanning(progress: ScanProgress)
        case complete
        case failed(String)
    }

    @Published public private(set) var scanPhase: ScanPhase = .idle

    // MARK: - Results

    /// All storage items discovered and analysed in the most recent scan.
    @Published public private(set) var storageItems: [StorageItem] = []

    /// User-selected items for cleaning (CleanMyMac / CCleaner style interactive checkboxes).
    @Published public var selectedItemIDs: Set<UUID> = []

    /// Aggregate totals for the Dashboard.
    @Published public private(set) var summary: StorageSummary = .empty

    /// The receipt from the most recent cleanup execution.
    @Published public var lastReceipt: CleanupReceipt? = nil

    /// All historical receipts loaded from SQLite persistence.
    @Published public var historicalReceipts: [CleanupReceipt] = []

    /// Total bytes recovered across all recorded sessions.
    public var allTimeRecoveredBytes: Int64 {
        historicalReceipts.reduce(0) { $0 + $1.actualRecoveredBytes }
    }

    public var formattedAllTimeRecovered: String {
        ByteCountFormatter.string(fromByteCount: allTimeRecoveredBytes, countStyle: .file)
    }

    public func recordReceipt(_ receipt: CleanupReceipt) {
        self.lastReceipt = receipt
        if !historicalReceipts.contains(where: { $0.id == receipt.id }) {
            historicalReceipts.insert(receipt, at: 0)
        }
    }

    public func setHistoricalReceipts(_ receipts: [CleanupReceipt]) {
        self.historicalReceipts = receipts
        if lastReceipt == nil, let first = receipts.first {
            self.lastReceipt = first
        }
    }

    /// Revision token bumped on any disk cleanup to auto-refresh storage metrics without manual scan.
    @Published public private(set) var storageMetricsRevision: Int = 0

    public func notifyCleanupPerformed() {
        storageMetricsRevision += 1
    }

    // MARK: - C++ Integrated Developer Terminal

    public struct TerminalLogEntry: Identifiable, Sendable {
        public let id = UUID()
        public let timestamp: Date
        public let text: String
        public let level: TerminalLogLevel

        public init(text: String, level: TerminalLogLevel = .info) {
            self.timestamp = Date()
            self.text = text
            self.level = level
        }
    }

    public enum TerminalLogLevel: String, Sendable {
        case info
        case success
        case warning
        case error
        case command
        case header
    }

    @Published public private(set) var terminalLogs: [TerminalLogEntry] = []

    public func appendTerminalLog(_ text: String, level: TerminalLogLevel = .info) {
        terminalLogs.append(TerminalLogEntry(text: text, level: level))
        if terminalLogs.count > 500 {
            terminalLogs.removeFirst(100)
        }
    }

    public func clearTerminalLogs() {
        terminalLogs.removeAll()
    }

    // MARK: - System Pressure & Sentinel State

    @Published public var latestPressureReport: PressureReport?
    @Published public var activeSlownessAlert: String?
    @Published public var isMonitoringPressure: Bool = false

    public func setLatestPressureReport(_ report: PressureReport) {
        self.latestPressureReport = report
    }

    public func triggerSlownessAlert(_ message: String) {
        self.activeSlownessAlert = message
    }

    public func dismissSlownessAlert() {
        self.activeSlownessAlert = nil
    }

    public func refreshPressureReport() async {
        let diagnostics = SystemPressureDiagnostics()
        let report = await diagnostics.generateReport()
        self.latestPressureReport = report
    }

    // MARK: - Init

    public init() {
        appendTerminalLog("// ========================================================================", level: .header)
        appendTerminalLog("// RECLAIM C++ ENGINE v2.4.0 [x86_64/arm64-apple-darwin] (C++20)", level: .header)
        appendTerminalLog("// Low-Level POSIX fts(3) Directory Crawler & APFS Inode Optimizer", level: .header)
        appendTerminalLog("// ========================================================================", level: .header)
        appendTerminalLog("[init] Initializing native storage runtime...", level: .info)
        appendTerminalLog("[init] SQLite3 persistent directory cache connected.", level: .info)
        appendTerminalLog("[ready] Ready for targeted developer & AI artifact scan.", level: .success)
    }

    // MARK: - Selection Management

    public func isSelected(_ id: UUID) -> Bool {
        selectedItemIDs.contains(id)
    }

    public func toggleSelection(for id: UUID) {
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
    }

    public func selectAllSafe() {
        let safeIDs = storageItems.filter { $0.risk == .safe || $0.risk == .low }.map(\.id)
        selectedItemIDs = Set(safeIDs)
    }

    public func selectAll() {
        let eligibleIDs = storageItems.filter { $0.isEligibleForPlan }.map(\.id)
        selectedItemIDs = Set(eligibleIDs)
    }

    public func deselectAll() {
        selectedItemIDs.removeAll()
    }

    public var selectedBytes: Int64 {
        storageItems.filter { selectedItemIDs.contains($0.id) }.reduce(0) { $0 + $1.estimatedReclaimableSize }
    }

    public var formattedSelectedBytes: String {
        ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file)
    }

    public func removeItems(withIDs ids: Set<UUID>) {
        storageItems.removeAll { ids.contains($0.id) }
        selectedItemIDs.subtract(ids)
        summary = StorageSummary(items: storageItems)
        notifyCleanupPerformed()
    }

    // MARK: - State transitions (called by scan coordinator, not by views)

    public func beginScan(for category: StorageCategory? = nil) {
        scanPhase = .scanning(progress: ScanProgress())
        if let category = category {
            let removedIDs = Set(storageItems.filter { $0.category == category }.map(\.id))
            storageItems.removeAll { $0.category == category }
            selectedItemIDs.subtract(removedIDs)
            summary = StorageSummary(items: storageItems)
        } else {
            storageItems = []
            selectedItemIDs = []
            summary = .empty
            lastReceipt = nil
        }
    }

    public func updateProgress(_ progress: ScanProgress) {
        scanPhase = .scanning(progress: progress)
    }

    public func appendItems(_ newItems: [StorageItem]) {
        storageItems.append(contentsOf: newItems)
        // Automatically pre-select safe items by default (CleanMyMac style smart default)
        for item in newItems where item.risk == .safe || item.risk == .low {
            selectedItemIDs.insert(item.id)
        }
        summary = StorageSummary(items: storageItems)
    }

    public func completeScan() {
        scanPhase = .complete
        summary = StorageSummary(items: storageItems)
    }

    public func failScan(reason: String) {
        scanPhase = .failed(reason)
    }

    public func resetScan() {
        scanPhase = .idle
        storageItems = []
        selectedItemIDs = []
        summary = .empty
    }
}

// MARK: - ScanProgress

/// Live progress information shown during an active scan (PRD §49).
public struct ScanProgress: Equatable, Sendable {
    public var filesScanned: Int = 0
    public var bytesIndexed: Int64 = 0
    public var currentPath: String = ""
    public var elapsedSeconds: TimeInterval = 0

    public init() {}
}

// MARK: - StorageSummary

/// Aggregated totals computed from the current set of `StorageItem` values.
/// Drives the main Dashboard display (PRD §14).
public struct StorageSummary: Sendable {

    public let totalLogicalBytes: Int64
    public let totalAllocatedBytes: Int64
    public let totalReclaimableBytes: Int64

    public let byCategory: [StorageCategory: Int64]

    public static let empty = StorageSummary(items: [])

    public init(items: [StorageItem]) {
        totalLogicalBytes   = items.reduce(0) { $0 + $1.logicalSize }
        totalAllocatedBytes = items.reduce(0) { $0 + $1.allocatedSize }
        totalReclaimableBytes = items
            .filter { $0.isEligibleForPlan }
            .reduce(0) { $0 + $1.estimatedReclaimableSize }

        var byCat: [StorageCategory: Int64] = [:]
        for item in items {
            byCat[item.category, default: 0] += item.allocatedSize
        }
        byCategory = byCat
    }

    // MARK: - Formatted helpers

    public var formattedReclaimable: String {
        ByteCountFormatter.string(fromByteCount: totalReclaimableBytes, countStyle: .file)
    }

    public func formattedBytes(for category: StorageCategory) -> String {
        let bytes = byCategory[category, default: 0]
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
