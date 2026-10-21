// SafetyPipelineTests.swift
// ReclaimTests
//
// Verifies that protected credentials and critical paths are NEVER recommended for deletion
// and are strictly rejected at all stages of the pipeline.

import Foundation
@testable import Reclaim

func runSafetyPipelineTests(_ r: TestRunner) async {
    print("\nSafety Pipeline")

    await r.asyncTest("Protected fixture files are strictly flagged and excluded from cleanup recommendations") {
        let container = await DependencyContainer.createWithDefaultAnalyzers()
        let coordinator = ScanCoordinator(analyzerRegistry: container.analyzerRegistry)

        let currentDir = FileManager.default.currentDirectoryPath
        let protectedFixturesURL = URL(fileURLWithPath: "\(currentDir)/Tests/Fixtures/protected")
        let context = AnalysisContext(rootURL: protectedFixturesURL)

        var scannedResults: [AnalysisResult] = []
        for await result in coordinator.scanAndAnalyze(rootURL: protectedFixturesURL, context: context) {
            scannedResults.append(result)
        }

        try r.expect(!scannedResults.isEmpty, "Should scan protected fixtures")

        for result in scannedResults {
            // Every item in the protected directory must be classified as protected
            try r.expectEqual(result.item.risk, .protected, "Item at \(result.item.path) must be protected")
            try r.expect(!result.isCleanupCandidate, "Item at \(result.item.path) must not be a cleanup candidate")
            try r.expect(!result.item.isEligibleForPlan, "Item at \(result.item.path) must not be eligible for plan")
        }

        // Even with an enormous target, none of these should be in a plan
        let recommendationEngine = RecommendationEngine()
        let plan = recommendationEngine.createPlan(targetBytes: 1_000_000_000, items: scannedResults.map(\.item))
        try r.expectEqual(plan.candidates.count, 0, "No protected items should be in recommendation plan")

        // If a plan is maliciously crafted with protected items, executor dry-run must filter them out
        let forcedCandidate = CleanupCandidate(item: scannedResults.first!.item)
        let forcedPlan = ReclaimPlan(targetBytes: 1000, candidates: [forcedCandidate])
        let executor = CleanupExecutor(useTrash: true)
        let dryRun = executor.dryRun(plan: forcedPlan)
        try r.expectEqual(dryRun.items.count, 0, "Dry run must filter out protected items")
    }
}
