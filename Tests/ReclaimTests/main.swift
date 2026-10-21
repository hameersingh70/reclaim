// main.swift
// Tests/ReclaimTests
//
// Self-contained test runner for Phase 1.
// No XCTest or Testing framework required — runs with Swift Command Line Tools.
// Uses @main async struct — the idiomatic Swift 6 entry point for async executables.

import Foundation
import Reclaim

// MARK: - Mini test harness

final class TestRunner: @unchecked Sendable {
    private(set) var passed = 0
    private(set) var failed = 0

    func test(_ name: String, _ body: () throws -> Void) {
        do {
            try body()
            print("  ✓ \(name)")
            passed += 1
        } catch {
            print("  ✗ \(name): \(error)")
            failed += 1
        }
    }

    func asyncTest(_ name: String, _ body: () async throws -> Void) async {
        do {
            try await body()
            print("  ✓ \(name)")
            passed += 1
        } catch {
            print("  ✗ \(name): \(error)")
            failed += 1
        }
    }

    struct Fail: Error {
        let message: String
        var localizedDescription: String { message }
    }

    func expect(_ condition: Bool, _ message: String = "Expectation failed") throws {
        if !condition { throw Fail(message: message) }
    }

    func expectEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "") throws {
        if a != b { throw Fail(message: message.isEmpty ? "\(a) != \(b)" : message) }
    }

    func expectNotEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "") throws {
        if a == b { throw Fail(message: message.isEmpty ? "\(a) should not equal \(b)" : message) }
    }

    func expectLessThan<T: Comparable>(_ a: T, _ b: T, _ message: String = "") throws {
        if !(a < b) { throw Fail(message: message.isEmpty ? "\(a) is not less than \(b)" : message) }
    }
}

// MARK: - StorageItem Tests

func runStorageItemTests(_ r: TestRunner) {
    print("\nStorageItem")

    r.test("Logical and allocated sizes are stored separately") {
        let item = StorageItem(path: "/tmp/test", logicalSize: 1_000, allocatedSize: 4_096)
        try r.expectEqual(item.logicalSize, 1_000)
        try r.expectEqual(item.allocatedSize, 4_096)
        try r.expectNotEqual(item.logicalSize, item.allocatedSize)
    }

    r.test("Estimated reclaimable size defaults to allocated size") {
        let item = StorageItem(path: "/tmp/test", logicalSize: 500, allocatedSize: 4_096)
        try r.expectEqual(item.estimatedReclaimableSize, 4_096)
    }

    r.test("Estimated reclaimable size can be less than allocated (partial cleanup)") {
        let item = StorageItem(path: "/tmp/gradle", logicalSize: 10_000,
                               allocatedSize: 12_288, estimatedReclaimableSize: 8_192)
        try r.expectEqual(item.estimatedReclaimableSize, 8_192)
        try r.expectLessThan(item.estimatedReclaimableSize, item.allocatedSize)
    }

    r.test("Size values do not overflow Int64 for 500 GB") {
        let largeSize: Int64 = 500 * 1_073_741_824
        let item = StorageItem(path: "/tmp/large", logicalSize: largeSize, allocatedSize: largeSize)
        try r.expectEqual(item.logicalSize, largeSize)
        try r.expect(item.logicalSize > 0)
    }

    r.test("Default risk is .unknown") {
        let item = StorageItem(path: "/tmp/x", logicalSize: 0, allocatedSize: 0)
        try r.expectEqual(item.risk, .unknown)
    }

    r.test("Default category is .generic") {
        let item = StorageItem(path: "/tmp/x", logicalSize: 0, allocatedSize: 0)
        try r.expectEqual(item.category, .generic)
    }

    r.test("UNKNOWN risk is not eligible for automatic plan") {
        let item = StorageItem(path: "/tmp/x", logicalSize: 0, allocatedSize: 0, risk: .unknown)
        try r.expect(!item.isEligibleForPlan)
    }

    r.test("PROTECTED risk is not eligible for automatic plan") {
        let item = StorageItem(path: "/bin", logicalSize: 0, allocatedSize: 0, risk: .protected)
        try r.expect(!item.isEligibleForPlan)
    }

    r.test("HIGH risk is not eligible for automatic plan") {
        let item = StorageItem(path: "/tmp/vol", logicalSize: 0, allocatedSize: 0, risk: .high)
        try r.expect(!item.isEligibleForPlan)
    }

    r.test("SAFE risk is eligible for automatic plan") {
        let item = StorageItem(path: "/tmp/cache", logicalSize: 0, allocatedSize: 0, risk: .safe)
        try r.expect(item.isEligibleForPlan)
    }

    r.test("LOW risk is eligible for automatic plan") {
        let item = StorageItem(path: "/tmp/cache", logicalSize: 0, allocatedSize: 0, risk: .low)
        try r.expect(item.isEligibleForPlan)
    }

    r.test("Item with no analyzerID is not analysed") {
        let item = StorageItem(path: "/tmp/x", logicalSize: 0, allocatedSize: 0)
        try r.expect(!item.isAnalysed)
    }

    r.test("Item with analyzerID is analysed") {
        let item = StorageItem(path: "/tmp/x", logicalSize: 0, allocatedSize: 0,
                               analyzerID: "com.reclaim.analyzers.gradle")
        try r.expect(item.isAnalysed)
    }

    r.test("InodeKey equality based on device and inode") {
        let k1 = InodeKey(device: 1, inode: 42)
        let k2 = InodeKey(device: 1, inode: 42)
        let k3 = InodeKey(device: 1, inode: 99)
        try r.expectEqual(k1, k2)
        try r.expectNotEqual(k1, k3)
    }

    r.test("InodeKey is hashable — usable in a Set for deduplication") {
        var seen = Set<InodeKey>()
        let key = InodeKey(device: 2, inode: 100)
        seen.insert(key)
        try r.expect(seen.contains(key))
    }

    r.test("Formatted allocated size string is non-empty") {
        let item = StorageItem(path: "/tmp/x", logicalSize: 0, allocatedSize: 1_048_576)
        try r.expect(!item.formattedAllocatedSize.isEmpty)
    }
}

// MARK: - StorageRiskLevel Tests

func runStorageRiskLevelTests(_ r: TestRunner) {
    print("\nStorageRiskLevel")

    for level in StorageRiskLevel.allCases {
        r.test("displayLabel non-empty for .\(level)") {
            try r.expect(!level.displayLabel.isEmpty)
        }
        r.test("accessibilityIcon non-empty for .\(level)") {
            try r.expect(!level.accessibilityIcon.isEmpty)
        }
    }

    r.test("PROTECTED is not eligible for plan") {
        try r.expect(!StorageRiskLevel.protected.isEligibleForAutomaticPlan)
    }
    r.test("UNKNOWN is not eligible for plan") {
        try r.expect(!StorageRiskLevel.unknown.isEligibleForAutomaticPlan)
    }
    r.test("HIGH is not eligible for plan") {
        try r.expect(!StorageRiskLevel.high.isEligibleForAutomaticPlan)
    }
    r.test("SAFE is eligible for plan") {
        try r.expect(StorageRiskLevel.safe.isEligibleForAutomaticPlan)
    }
    r.test("LOW is eligible for plan") {
        try r.expect(StorageRiskLevel.low.isEligibleForAutomaticPlan)
    }
    r.test("MEDIUM is eligible for plan") {
        try r.expect(StorageRiskLevel.medium.isEligibleForAutomaticPlan)
    }
    r.test("Codable round-trip preserves all cases") {
        for level in StorageRiskLevel.allCases {
            let encoded = try JSONEncoder().encode(level)
            let decoded = try JSONDecoder().decode(StorageRiskLevel.self, from: encoded)
            try r.expectEqual(level, decoded)
        }
    }
}

// MARK: - AnalysisContext Tests

func runAnalysisContextTests(_ r: TestRunner) {
    print("\nAnalysisContext")

    let fixedHome = URL(fileURLWithPath: "/Users/testuser")

    r.test("Stale date is in the past relative to injected now") {
        let now = Date()
        let ctx = AnalysisContext(rootURL: URL(fileURLWithPath: "/tmp"),
                                  homeURL: fixedHome, now: now, staleThresholdDays: 90)
        try r.expectLessThan(ctx.staleDate, now)
    }

    r.test("Stale date is exactly N days before injected now") {
        let now = Date()
        let ctx = AnalysisContext(rootURL: URL(fileURLWithPath: "/tmp"),
                                  homeURL: fixedHome, now: now, staleThresholdDays: 30)
        let expected = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let diff = abs(ctx.staleDate.timeIntervalSince1970 - expected.timeIntervalSince1970)
        try r.expect(diff < 1.0, "Stale date off by \(diff)s")
    }

    r.test("Tilde expansion uses injected homeURL, not process home") {
        let ctx = AnalysisContext(rootURL: URL(fileURLWithPath: "/tmp"), homeURL: fixedHome)
        let resolved = ctx.resolving(tildeRelativePath: "~/.gradle/caches")
        try r.expectEqual(resolved.path, "/Users/testuser/.gradle/caches")
    }

    r.test("Absolute path passes through resolving() unchanged") {
        let ctx = AnalysisContext(rootURL: URL(fileURLWithPath: "/tmp"), homeURL: fixedHome)
        let resolved = ctx.resolving(tildeRelativePath: "/absolute/path")
        try r.expectEqual(resolved.path, "/absolute/path")
    }
}

// MARK: - AnalyzerRegistry Tests — stub analyzers

private struct AlwaysClaimsAnalyzer: StorageAnalyzer {
    let id = "com.reclaim.test.always"
    let displayName = "AlwaysClaims"
    func canAnalyze(_ item: StorageItem) -> Bool { true }
    func analyze(item: StorageItem, context: AnalysisContext) async throws -> AnalysisResult {
        let enriched = StorageItem(
            id: item.id, path: item.path,
            logicalSize: item.logicalSize, allocatedSize: item.allocatedSize,
            category: .gradle, analyzerID: id,
            risk: .safe, recoverability: .regeneratable,
            whatIsThis: "Test item"
        )
        let ev = Evidence(kind: .pathMatch, description: "Claimed by AlwaysClaims")
        return AnalysisResult(item: enriched, evidence: [ev], isCleanupCandidate: true)
    }
}

private struct NeverClaimsAnalyzer: StorageAnalyzer {
    let id = "com.reclaim.test.never"
    let displayName = "NeverClaims"
    func canAnalyze(_ item: StorageItem) -> Bool { false }
    func analyze(item: StorageItem, context: AnalysisContext) async throws -> AnalysisResult {
        struct UnexpectedCall: Error {}
        throw UnexpectedCall()
    }
}

private struct ThrowingAnalyzer: StorageAnalyzer {
    let id = "com.reclaim.test.throwing"
    let displayName = "ThrowingAnalyzer"
    func canAnalyze(_ item: StorageItem) -> Bool { true }
    func analyze(item: StorageItem, context: AnalysisContext) async throws -> AnalysisResult {
        throw AnalyzerError.internalFailure("Simulated failure")
    }
}

private func makeCtx() -> AnalysisContext {
    AnalysisContext(rootURL: URL(fileURLWithPath: "/tmp"))
}
private func makeItem(path: String = "/tmp/test") -> StorageItem {
    StorageItem(path: path, logicalSize: 1_000, allocatedSize: 4_096)
}

func runAnalyzerRegistryTests(_ r: TestRunner) async {
    print("\nAnalyzerRegistry")

    await r.asyncTest("Empty registry has zero count") {
        let reg = AnalyzerRegistry()
        let count = await reg.count
        try r.expectEqual(count, 0)
    }

    await r.asyncTest("Registered analyzer appears in count and ID list") {
        let reg = AnalyzerRegistry()
        await reg.register(AlwaysClaimsAnalyzer())
        let count = await reg.count
        let ids = await reg.registeredIDs
        try r.expectEqual(count, 1)
        try r.expect(ids.contains("com.reclaim.test.always"))
    }

    await r.asyncTest("Claiming analyzer enriches item correctly") {
        let reg = AnalyzerRegistry()
        await reg.register(AlwaysClaimsAnalyzer())
        let result = await reg.analyze(item: makeItem(), context: makeCtx())
        try r.expectEqual(result.item.analyzerID, "com.reclaim.test.always")
        try r.expectEqual(result.item.risk, .safe)
        try r.expect(result.isCleanupCandidate)
        try r.expect(!result.evidence.isEmpty)
    }

    await r.asyncTest("Unclaimed item returns UNKNOWN risk and is not a cleanup candidate") {
        let reg = AnalyzerRegistry()
        await reg.register(NeverClaimsAnalyzer())
        let result = await reg.analyze(item: makeItem(), context: makeCtx())
        try r.expectEqual(result.item.risk, .unknown)
        try r.expect(!result.isCleanupCandidate)
        try r.expect(result.rejectionReason != nil)
    }

    await r.asyncTest("Empty registry returns item path unchanged with UNKNOWN risk") {
        let reg = AnalyzerRegistry()
        let result = await reg.analyze(item: makeItem(path: "/some/path"), context: makeCtx())
        try r.expectEqual(result.item.path, "/some/path")
        try r.expectEqual(result.item.risk, .unknown)
        try r.expect(!result.isCleanupCandidate)
    }

    await r.asyncTest("Throwing analyzer does not crash — returns UNKNOWN with error evidence") {
        let reg = AnalyzerRegistry()
        await reg.register(ThrowingAnalyzer())
        let result = await reg.analyze(item: makeItem(), context: makeCtx())
        try r.expectEqual(result.item.risk, .unknown)
        try r.expect(!result.isCleanupCandidate)
        try r.expect(!result.evidence.isEmpty)
    }

    await r.asyncTest("First registered claiming analyzer wins") {
        let reg = AnalyzerRegistry()
        await reg.register(NeverClaimsAnalyzer())
        await reg.register(AlwaysClaimsAnalyzer())
        let result = await reg.analyze(item: makeItem(), context: makeCtx())
        try r.expectEqual(result.item.analyzerID, "com.reclaim.test.always")
    }

    await r.asyncTest("Lookup by ID returns correct analyzer or nil") {
        let reg = AnalyzerRegistry()
        await reg.register(AlwaysClaimsAnalyzer())
        let found = await reg.analyzer(withID: "com.reclaim.test.always")
        let notFound = await reg.analyzer(withID: "com.reclaim.test.missing")
        try r.expect(found != nil)
        try r.expect(notFound == nil)
    }
}

// MARK: - Entry point

let runner = TestRunner()

runStorageItemTests(runner)
runStorageRiskLevelTests(runner)
runAnalysisContextTests(runner)

// Run async tests synchronously via a top-level await (Swift 6 supports this in main.swift)
await runAnalyzerRegistryTests(runner)
await runFileScannerTests(runner)
runDatabaseTests(runner)
runGenericCategorizerTests(runner)
await runScanCoordinatorTests(runner)
await runAnalyzerTests(runner)
runSafetyEngineTests(runner)
runRecommendationTests(runner)
runCleanupTests(runner)
await runFullPipelineTests(runner)
await runSafetyPipelineTests(runner)
await runPerformanceTests(runner)
await runNewAnalyzerTests(runner)
await runSystemStorageTests(runner)
registerProjectWorkspaceScannerTests(in: runner)
registerSelfImprovementSuiteTests(in: runner)
await runSystemPressureDiagnosticsTests(runner)

print("\n─────────────────────────────────────")
print("Results: \(runner.passed) passed, \(runner.failed) failed")
print("─────────────────────────────────────")

exit(runner.failed > 0 ? 1 : 0)
