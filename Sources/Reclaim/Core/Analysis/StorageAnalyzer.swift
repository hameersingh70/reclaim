// StorageAnalyzer.swift
// Core/Analysis
//
// The plugin protocol every ecosystem analyzer must conform to.
// PRD §8: adding a new ecosystem must not require modifying the scanner.

import Foundation

/// A domain-specific analyzer that classifies and enriches a `StorageItem`.
///
/// Analyzers are the sole source of domain knowledge about specific ecosystems
/// (Docker, Xcode, Gradle, Node, etc.). The generic scanner produces raw
/// `StorageItem` values; analyzers are responsible for adding meaning.
///
/// **Safety contract (PRD §4.2)**
/// Analyzers produce deterministic classifications based on explicit rules.
/// LLMs and heuristic guesses must not influence `risk` or `isCleanupCandidate`.
///
/// **Concurrency**
/// Conforming types must be `Sendable`. Analysis runs on a background executor.
public protocol StorageAnalyzer: Sendable {

    /// Unique stable identifier for this analyzer.
    /// Used to attribute `StorageItem.analyzerID` and in cleanup receipts.
    /// Example: `"com.reclaim.analyzers.gradle"`
    var id: String { get }

    /// Human-readable name shown in the UI and logs.
    var displayName: String { get }

    /// Returns `true` when this analyzer wants to claim and enrich `item`.
    ///
    /// Must be fast and non-throwing — called for every scanned item.
    /// Must not perform any I/O.
    func canAnalyze(_ item: StorageItem) -> Bool

    /// Performs the full analysis of `item` within `context`.
    ///
    /// - Returns: An `AnalysisResult` with the enriched item, evidence, and
    ///   a cleanup recommendation. Never returns `nil` — return a result with
    ///   `isCleanupCandidate: false` and a `rejectionReason` if not applicable.
    /// - Throws: `AnalyzerError` for unrecoverable failures.
    ///   Transient I/O errors for optional metadata should be caught internally
    ///   and reflected in the evidence records rather than thrown.
    func analyze(
        item: StorageItem,
        context: AnalysisContext
    ) async throws -> AnalysisResult
}

// MARK: - AnalyzerError

/// Errors that a `StorageAnalyzer` may throw during analysis.
public enum AnalyzerError: Error, Sendable {

    /// The analyzer requires a file or directory that does not exist.
    case requiredPathMissing(String)

    /// A metadata file was found but could not be parsed.
    case metadataParseFailure(path: String, reason: String)

    /// The item's path was outside the expected root for this analyzer.
    case unexpectedPath(String)

    /// A generic failure with a descriptive message.
    case internalFailure(String)
}
