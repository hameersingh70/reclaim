// AnalysisResult.swift
// Core/Analysis
//
// The structured output that every StorageAnalyzer produces for a given item.
// Results include the enriched StorageItem plus supporting evidence records.

import Foundation

/// The outcome produced by a `StorageAnalyzer` for a single `StorageItem`.
public struct AnalysisResult: Sendable {

    /// The enriched item with all classification fields populated by the analyzer.
    public let item: StorageItem

    /// Supporting evidence records that explain why the classification was made.
    /// Shown in the Inspector panel under "Evidence" (PRD §48).
    public let evidence: [Evidence]

    /// Whether the analyzer recommends this item as a cleanup candidate.
    public let isCleanupCandidate: Bool

    /// Reason why the analyzer did NOT recommend cleanup, if applicable.
    /// Used to populate the "rejected candidate" log required by PRD §18.6.
    public let rejectionReason: String?

    public init(
        item: StorageItem,
        evidence: [Evidence] = [],
        isCleanupCandidate: Bool,
        rejectionReason: String? = nil
    ) {
        self.item = item
        self.evidence = evidence
        self.isCleanupCandidate = isCleanupCandidate
        self.rejectionReason = rejectionReason
    }
}

// MARK: - Evidence

/// A single piece of evidence that supports an analysis classification.
///
/// Displayed in the Inspector panel so the user can verify why the system
/// made a given recommendation.
public struct Evidence: Codable, Sendable {

    public enum EvidenceKind: String, Codable, Sendable {
        /// A file or directory was found at an expected path.
        case pathMatch
        /// A tool version was detected from a metadata file or binary.
        case toolVersionDetected
        /// A lockfile was found, confirming dependencies are reconstructible.
        case lockfilePresent
        /// The item has not been accessed within a configurable threshold.
        case staleByAge
        /// A configuration file was inspected for content.
        case configInspected
        /// A running process was detected that owns this storage.
        case processRunning
        /// A custom evidence note from the analyzer.
        case note
    }

    public let kind: EvidenceKind
    public let description: String
    /// Optional path that this evidence refers to (e.g. the lockfile path).
    public let referencePath: String?

    public init(
        kind: EvidenceKind,
        description: String,
        referencePath: String? = nil
    ) {
        self.kind = kind
        self.description = description
        self.referencePath = referencePath
    }
}
