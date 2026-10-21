// RecommendationEngine.swift
// Core/Recommendation
//
// Solves for the lowest-risk combination of cleanup candidates to free
// a user-requested target amount of storage (PRD §17).

import Foundation

public struct RecommendationEngine: Sendable {

    public init() {}

    /// Generates a ReclaimPlan to free at least `targetBytes` using the lowest-risk
    /// combination of candidate items.
    ///
    /// Never automatically includes .high, .protected, or .unknown items.
    public func createPlan(targetBytes: Int64, items: [StorageItem]) -> ReclaimPlan {
        // Filter strictly to items eligible for automatic planning
        let eligible = items.filter { $0.isEligibleForPlan }

        // Sort candidates by priority (lowest risk/friction first), then largest size first
        let candidates = eligible.map { CleanupCandidate(item: $0) }
            .sorted { (a, b) -> Bool in
                if a.priority != b.priority {
                    return a.priority < b.priority
                }
                return a.reclaimableBytes > b.reclaimableBytes
            }

        var selected: [CleanupCandidate] = []
        var accumulatedBytes: Int64 = 0

        for candidate in candidates {
            if accumulatedBytes >= targetBytes {
                break
            }
            selected.append(candidate)
            accumulatedBytes += candidate.reclaimableBytes
        }

        return ReclaimPlan(targetBytes: targetBytes, candidates: selected)
    }
}
