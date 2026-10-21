// CleanupTests.swift
// ReclaimTests

import Foundation
@testable import Reclaim

func runCleanupTests(_ r: TestRunner) {
    print("\nCleanup (Dry-run)")

    let executor = CleanupExecutor(useTrash: true)

    r.test("Dry run produces structured report without touching files on disk") {
        let currentDir = FileManager.default.currentDirectoryPath
        let fixtureFile = "\(currentDir)/Tests/Fixtures/generic/old-large-file.bin"

        try r.expect(FileManager.default.fileExists(atPath: fixtureFile))

        let item = StorageItem(
            path: fixtureFile,
            logicalSize: 100,
            allocatedSize: 4096,
            estimatedReclaimableSize: 4096,
            risk: .safe,
            recoverability: .regeneratable,
            whatIsThis: "Generic test cache file",
            recoveryInstruction: "Re-downloaded automatically"
        )

        let plan = ReclaimPlan(targetBytes: 4000, candidates: [CleanupCandidate(item: item)])
        let report = executor.dryRun(plan: plan)

        try r.expectEqual(report.items.count, 1)
        try r.expectEqual(report.totalAllocatedBytes, 4096)
        try r.expectEqual(report.totalEstimatedReclaimableBytes, 4096)
        try r.expectEqual(report.items.first?.path, fixtureFile)
        try r.expectEqual(report.items.first?.reason, "Generic test cache file")
        try r.expectEqual(report.items.first?.recoveryMechanism, "Re-downloaded automatically")

        // CRITICAL: File must still exist on disk after dry run!
        try r.expect(FileManager.default.fileExists(atPath: fixtureFile))
    }

    r.test("Dry run filters out protected paths even if submitted in a plan") {
        let sshPath = "/Users/test/.ssh/id_rsa"
        let protectedItem = StorageItem(path: sshPath, logicalSize: 100, allocatedSize: 4096, risk: .safe)
        let plan = ReclaimPlan(targetBytes: 4000, candidates: [CleanupCandidate(item: protectedItem)])

        let report = executor.dryRun(plan: plan)
        try r.expectEqual(report.items.count, 0)
    }
}
