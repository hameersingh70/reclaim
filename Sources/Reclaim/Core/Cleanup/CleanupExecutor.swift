// CleanupExecutor.swift
// Core/Cleanup
//
// Coordinates dry-run previews and safe Trash-first deletions per PRD §19 & §20.
// Hardcoded safety checks guarantee protected paths cannot be deleted.

import Foundation

public final class CleanupExecutor: Sendable {
    public let useTrash: Bool
    public let safetyEngine: SafetyEngine

    public init(useTrash: Bool = true, safetyEngine: SafetyEngine = SafetyEngine()) {
        self.useTrash = useTrash
        self.safetyEngine = safetyEngine
    }

    /// Performs a completely non-destructive dry run previewing what would happen.
    public func dryRun(plan: ReclaimPlan) -> DryRunReport {
        // Enforce safety: filter out any candidate whose path is protected
        let safeCandidates = plan.candidates.filter { !safetyEngine.isProtected(path: $0.item.path) }
        let safePlan = ReclaimPlan(targetBytes: plan.targetBytes, candidates: safeCandidates)
        return DryRunReport(plan: safePlan)
    }

    /// Executes the cleanup plan.
    /// Uses FileManager.trashItem by default for safety and recovery.
    public func execute(plan: ReclaimPlan) throws -> CleanupReceipt {
        var actions: [CleanupActionSummary] = []
        let fileManager = FileManager.default

        for candidate in plan.candidates {
            let item = candidate.item

            // Safety guard: never touch protected paths
            if safetyEngine.isProtected(path: item.path) || item.risk == .protected {
                actions.append(CleanupActionSummary(
                    path: item.path,
                    description: "Skipped: Protected by SafetyEngine",
                    reclaimedBytes: 0,
                    success: false,
                    recoveryInstruction: nil
                ))
                continue
            }

            let url = URL(fileURLWithPath: item.path)
            guard fileManager.fileExists(atPath: item.path) else {
                continue
            }

            var success = false
            do {
                if useTrash {
                    try fileManager.trashItem(at: url, resultingItemURL: nil)
                    success = true
                } else {
                    try fileManager.removeItem(at: url)
                    success = true
                }
            } catch {
                success = false
            }

            actions.append(CleanupActionSummary(
                path: item.path,
                description: item.whatIsThis ?? item.category.displayName,
                reclaimedBytes: success ? item.allocatedSize : 0,
                success: success,
                recoveryInstruction: item.recoveryInstruction
            ))
        }

        let totalRecovered = actions.filter(\.success).reduce(0) { $0 + $1.reclaimedBytes }
        return CleanupReceipt(
            beforeAvailableBytes: 0,
            afterAvailableBytes: totalRecovered,
            actions: actions
        )
    }
}
