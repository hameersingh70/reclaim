// ScanCoordinatorTests.swift
// ReclaimTests

import Foundation
@testable import Reclaim

func runScanCoordinatorTests(_ r: TestRunner) async {
    print("\nScanCoordinator")

    await r.asyncTest("Can be initialized and streams analysis results over fixtures") {
        let registry = AnalyzerRegistry()
        await registry.register(GradleAnalyzer())
        let coordinator = ScanCoordinator(analyzerRegistry: registry)

        let fixturesURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Tests/Fixtures/gradle")
        let context = AnalysisContext(rootURL: fixturesURL)

        var count = 0
        var foundGradleItem = false

        for await result in coordinator.scanAndAnalyze(rootURL: fixturesURL, context: context) {
            count += 1
            if result.item.category == .gradle {
                foundGradleItem = true
            }
        }

        try r.expect(count > 0, "Coordinator should yield scanned items")
        try r.expect(foundGradleItem, "Should identify gradle category")
    }
}
