// RecommendationTests.swift
// ReclaimTests

import Foundation
@testable import Reclaim

func runRecommendationTests(_ r: TestRunner) {
    print("\nRecommendationEngine")

    let engine = RecommendationEngine()

    r.test("Selects lowest-risk items first and satisfies target") {
        let safeItem1 = StorageItem(path: "/cache1", logicalSize: 1000, allocatedSize: 1000, estimatedReclaimableSize: 1000, risk: .safe, recoverability: .regeneratable)
        let safeItem2 = StorageItem(path: "/cache2", logicalSize: 2000, allocatedSize: 2000, estimatedReclaimableSize: 2000, risk: .safe, recoverability: .regeneratable)
        let lowItem = StorageItem(path: "/runtime", logicalSize: 5000, allocatedSize: 5000, estimatedReclaimableSize: 5000, risk: .low, recoverability: .redownloadable)
        let mediumItem = StorageItem(path: "/archive", logicalSize: 8000, allocatedSize: 8000, estimatedReclaimableSize: 8000, risk: .medium, recoverability: .applicationState)

        let items = [mediumItem, lowItem, safeItem1, safeItem2]

        // Target: 2500 bytes. Should pick safeItem2 (2000) then safeItem1 (1000) -> total 3000 >= 2500, no low or medium needed!
        let plan = engine.createPlan(targetBytes: 2500, items: items)
        try r.expect(plan.isTargetMet)
        try r.expectEqual(plan.candidates.count, 2)
        try r.expectEqual(plan.overallRisk, .safe)
        try r.expectEqual(plan.totalReclaimableBytes, 3000)
    }

    r.test("Never includes high, protected, or unknown items in automatic plan") {
        let protectedItem = StorageItem(path: "/Users/test/.ssh/id_rsa", logicalSize: 1000, allocatedSize: 1000, estimatedReclaimableSize: 1000, risk: .protected)
        let highItem = StorageItem(path: "/vol", logicalSize: 5000, allocatedSize: 5000, estimatedReclaimableSize: 5000, risk: .high)
        let unknownItem = StorageItem(path: "/unk", logicalSize: 2000, allocatedSize: 2000, estimatedReclaimableSize: 2000, risk: .unknown)
        let safeItem = StorageItem(path: "/cache", logicalSize: 500, allocatedSize: 500, estimatedReclaimableSize: 500, risk: .safe, recoverability: .regeneratable)

        let items = [protectedItem, highItem, unknownItem, safeItem]

        // Even with a huge target of 100,000 bytes, only the safe item should be included
        let plan = engine.createPlan(targetBytes: 100_000, items: items)
        try r.expectEqual(plan.candidates.count, 1)
        try r.expectEqual(plan.candidates.first?.item.path, "/cache")
        try r.expect(!plan.isTargetMet)
    }
}
