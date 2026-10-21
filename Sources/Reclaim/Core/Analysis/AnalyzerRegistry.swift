// AnalyzerRegistry.swift
// Core/Analysis
//
// The central registry through which all StorageAnalyzers are registered
// and dispatched. Adding a new ecosystem means calling register() — no
// other file needs to change.
//
// PRD §8: "Adding another ecosystem must not require modifying the scanner."

import Foundation

/// Thread-safe registry that maps `StorageItem` values to the appropriate
/// `StorageAnalyzer` and dispatches analysis.
///
/// Analyzers are evaluated in registration order. The first analyzer whose
/// `canAnalyze(_:)` returns `true` claims the item.
/// Items that no analyzer claims are returned with their original values
/// (risk: `.unknown`, category: `.generic`).
public actor AnalyzerRegistry {

    // MARK: - State

    private var analyzers: [any StorageAnalyzer] = []

    // MARK: - Init

    public init() {}

    // MARK: - Registration

    /// Register a new analyzer. Analyzers are evaluated in registration order.
    public func register(_ analyzer: some StorageAnalyzer) {
        analyzers.append(analyzer)
    }

    /// Register multiple analyzers at once.
    public func register(_ newAnalyzers: [any StorageAnalyzer]) {
        analyzers.append(contentsOf: newAnalyzers)
    }

    // MARK: - Dispatch

    /// Finds the first registered analyzer that can handle `item` and runs it.
    ///
    /// - Returns: The `AnalysisResult` from the claiming analyzer, or a
    ///   passthrough result (no enrichment) when no analyzer claims the item.
    public func analyze(
        item: StorageItem,
        context: AnalysisContext
    ) async -> AnalysisResult {
        for analyzer in analyzers {
            guard analyzer.canAnalyze(item) else { continue }
            do {
                return try await analyzer.analyze(item: item, context: context)
            } catch {
                // Analyzer failures must not crash the registry.
                // Return a conservative unknown result with the error as evidence.
                let failedItem = StorageItem(
                    id: item.id,
                    path: item.path,
                    logicalSize: item.logicalSize,
                    allocatedSize: item.allocatedSize,
                    estimatedReclaimableSize: 0,
                    createdAt: item.createdAt,
                    modifiedAt: item.modifiedAt,
                    accessedAt: item.accessedAt,
                    category: item.category,
                    analyzerID: analyzer.id,
                    risk: .unknown,
                    recoverability: .unknown,
                    isSymlink: item.isSymlink,
                    isHardLink: item.isHardLink,
                    inodeKey: item.inodeKey
                )
                let errorEvidence = Evidence(
                    kind: .note,
                    description: "Analyzer '\(analyzer.displayName)' failed: \(error.localizedDescription)"
                )
                return AnalysisResult(
                    item: failedItem,
                    evidence: [errorEvidence],
                    isCleanupCandidate: false,
                    rejectionReason: "Analyzer error — defaulting to UNKNOWN."
                )
            }
        }

        // No analyzer claimed this item — return as-is (generic/unknown).
        return AnalysisResult(
            item: item,
            evidence: [],
            isCleanupCandidate: false,
            rejectionReason: "No registered analyzer claimed this item."
        )
    }

    /// Returns the registered analyzer with the given `id`, or `nil`.
    public func analyzer(withID id: String) -> (any StorageAnalyzer)? {
        analyzers.first { $0.id == id }
    }

    /// Returns the count of registered analyzers.
    public var count: Int { analyzers.count }

    /// Returns the IDs of all registered analyzers in registration order.
    public var registeredIDs: [String] { analyzers.map(\.id) }
}
