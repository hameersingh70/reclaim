// FullPipelineTests.swift
// ReclaimTests
//
// End-to-end integration test exercising the full scan -> analyze -> safety -> recommend -> dry-run pipeline
// on the hermetic fixture tree in Tests/Fixtures/.

import Foundation
@testable import Reclaim

func runFullPipelineTests(_ r: TestRunner) async {
    print("\nE2E Full Pipeline")

    await r.asyncTest("Full pipeline: scan -> analyze -> safety -> recommend -> dry-run") {
        // 1. Setup DI container with all 5 default analyzers
        let container = await DependencyContainer.createWithDefaultAnalyzers()
        let coordinator = ScanCoordinator(analyzerRegistry: container.analyzerRegistry)

        let currentDir = FileManager.default.currentDirectoryPath
        let fixturesURL = URL(fileURLWithPath: "\(currentDir)/Tests/Fixtures")
        let context = AnalysisContext(rootURL: fixturesURL)

        // 2. Scan and stream analysis
        var analyzedItems: [StorageItem] = []
        var foundCategories = Set<StorageCategory>()

        for await result in coordinator.scanAndAnalyze(rootURL: fixturesURL, context: context) {
            analyzedItems.append(result.item)
            foundCategories.insert(result.item.category)
        }

        try r.expect(analyzedItems.count >= 10, "Expected at least 10 items in fixtures, found \(analyzedItems.count)")
        try r.expect(foundCategories.contains(.gradle), "Should detect Gradle items")
        try r.expect(foundCategories.contains(.node), "Should detect Node items")
        try r.expect(foundCategories.contains(.xcode), "Should detect Xcode items")

        // 3. Recommend a cleanup plan targeting 1000 bytes
        let recommendationEngine = RecommendationEngine()
        let plan = recommendationEngine.createPlan(targetBytes: 1000, items: analyzedItems)

        try r.expect(!plan.candidates.isEmpty, "Plan should find candidates from safe/low items")
        try r.expect(plan.isTargetMet, "Plan should reach 1000 bytes target from fixtures")

        // None of the selected candidates should be protected
        for candidate in plan.candidates {
            try r.expect(candidate.item.risk != .protected, "Protected item must never be in plan")
            try r.expect(candidate.item.risk != .high, "High risk item must never be in automatic plan")
            try r.expect(candidate.item.risk != .unknown, "Unknown risk item must never be in automatic plan")
        }

        // 4. Generate dry-run preview report
        let cleanupExecutor = CleanupExecutor(useTrash: true)
        let dryRunReport = cleanupExecutor.dryRun(plan: plan)

        try r.expectEqual(dryRunReport.items.count, plan.candidates.count)
        try r.expect(dryRunReport.totalEstimatedReclaimableBytes >= 1000)

        // 5. Verify persistence in SQLite
        let db = try Database(path: ":memory:")
        for candidate in plan.candidates {
            try db.save(item: candidate.item)
        }
        let savedCount = try db.queryInt("SELECT COUNT(*) FROM items")
        try r.expectEqual(savedCount, plan.candidates.count)

        // Save a mock receipt to DB
        let actions = dryRunReport.items.map {
            CleanupActionSummary(path: $0.path, description: $0.reason, reclaimedBytes: $0.allocatedSize, success: true)
        }
        let receipt = CleanupReceipt(beforeAvailableBytes: 50_000, afterAvailableBytes: 50_000 + dryRunReport.totalAllocatedBytes, actions: actions)
        try db.save(receipt: receipt)
        let receiptCount = try db.queryInt("SELECT COUNT(*) FROM receipts")
        try r.expectEqual(receiptCount, 1)
    }
}
