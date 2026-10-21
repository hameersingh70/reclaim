// HomebrewAnalyzer.swift
// Analyzers/Homebrew
//
// Detects Homebrew download caches and formula versions per PRD §9.
// Recommends standard brew cleanup mechanisms.

import Foundation

public struct HomebrewAnalyzer: StorageAnalyzer {
    public let id = "com.reclaim.analyzers.homebrew"
    public let displayName = "Homebrew Analyzer"

    public init() {}

    public func canAnalyze(_ item: StorageItem) -> Bool {
        let lower = item.path.lowercased()
        return lower.contains("/homebrew") || lower.contains("/cellar/") || lower.contains("/.homebrew")
    }

    public func analyze(item: StorageItem, context: AnalysisContext) async throws -> AnalysisResult {
        var enriched = item
        enriched.category = .homebrew
        enriched.analyzerID = id

        let lower = item.path.lowercased()
        var evidence: [Evidence] = []
        var isCandidate = false
        var rejectionReason: String? = nil

        if lower.contains("/caches/homebrew") || lower.contains("/downloads") {
            enriched.risk = .safe
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "Homebrew download cache"
            enriched.whyItExists = "Stores downloaded bottles and source tarballs."
            enriched.removalConsequence = "Reclaims disk space without breaking any installed packages."
            enriched.recoveryInstruction = "Packages will be re-downloaded if reinstalled. Recommended: run 'brew cleanup'."
            isCandidate = true
            evidence.append(Evidence(kind: .pathMatch, description: "Matched Homebrew cache/downloads"))
        } else if lower.contains("/cellar/") {
            enriched.risk = .low
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "Installed Homebrew formula"
            enriched.whyItExists = "Installed binaries and libraries for a Homebrew package."
            enriched.removalConsequence = "Removes this formula version. Prefer 'brew cleanup' to remove only stale versions."
            enriched.recoveryInstruction = "Reinstall using 'brew install <formula>'."
            isCandidate = true
            evidence.append(Evidence(kind: .pathMatch, description: "Matched Homebrew Cellar formula"))
        } else {
            enriched.risk = .medium
            enriched.recoverability = .unknown
            isCandidate = false
            rejectionReason = "Internal Homebrew infrastructure should not be deleted manually."
        }

        return AnalysisResult(
            item: enriched,
            evidence: evidence,
            isCleanupCandidate: isCandidate,
            rejectionReason: rejectionReason
        )
    }
}
