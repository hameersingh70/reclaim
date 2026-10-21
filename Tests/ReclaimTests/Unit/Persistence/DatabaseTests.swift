// DatabaseTests.swift
// ReclaimTests

import Foundation
@testable import Reclaim

func runDatabaseTests(_ r: TestRunner) {
    print("\nDatabase")

    r.test("Database opens in memory and creates schema") {
        let db = try Database(path: ":memory:")
        let itemsCount = try db.queryInt("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='items'")
        try r.expectEqual(itemsCount, 1)

        let receiptsCount = try db.queryInt("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='receipts'")
        try r.expectEqual(receiptsCount, 1)

        let historyCount = try db.queryInt("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='history'")
        try r.expectEqual(historyCount, 1)
    }

    r.test("Saves and counts items") {
        let db = try Database(path: ":memory:")
        let item = StorageItem(
            path: "/Users/test/cache",
            logicalSize: 1000,
            allocatedSize: 4096,
            category: .gradle,
            risk: .safe,
            recoverability: .regeneratable
        )
        try db.save(item: item)
        let count = try db.queryInt("SELECT COUNT(*) FROM items")
        try r.expectEqual(count, 1)
    }

    r.test("Saves and counts receipts") {
        let db = try Database(path: ":memory:")
        let action = CleanupActionSummary(path: "/Users/test/cache", description: "Gradle Cache", reclaimedBytes: 4096, success: true)
        let receipt = CleanupReceipt(beforeAvailableBytes: 10000, afterAvailableBytes: 14096, actions: [action])
        try db.save(receipt: receipt)
        let count = try db.queryInt("SELECT COUNT(*) FROM receipts")
        try r.expectEqual(count, 1)
    }

    r.test("Records history snapshots") {
        let db = try Database(path: ":memory:")
        try db.recordHistory(totalUsed: 200_000, available: 50_000, reclaimable: 20_000)
        let count = try db.queryInt("SELECT COUNT(*) FROM history")
        try r.expectEqual(count, 1)
    }

    // MARK: - Incremental Indexing Tests

    r.test("directory_cache table is created") {
        let db = try Database(path: ":memory:")
        let count = try db.queryInt("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='directory_cache'")
        try r.expectEqual(count, 1)
    }

    r.test("cachedMtime returns nil for never-indexed path") {
        let db = try Database(path: ":memory:")
        let result = db.cachedMtime(for: "/never/indexed/path")
        guard result == nil else {
            throw TestRunner.Fail(message: "Expected nil for un-indexed path, got \(result!)")
        }
    }

    r.test("updateMtime stores mtime and cachedMtime retrieves it") {
        let db = try Database(path: ":memory:")
        let testPath = "/tmp/reclaim_test_dir"
        let testMtime = 1_700_000_000.5
        db.updateMtime(for: testPath, mtime: testMtime)
        let retrieved = db.cachedMtime(for: testPath)
        guard let retrieved = retrieved else {
            throw TestRunner.Fail(message: "Expected cached mtime to be non-nil after update")
        }
        guard abs(retrieved - testMtime) < 0.001 else {
            throw TestRunner.Fail(message: "Stored mtime \(testMtime) != retrieved \(retrieved)")
        }
    }

    r.test("isDirectoryUnchanged returns false for un-indexed path") {
        let db = try Database(path: ":memory:")
        let result = db.isDirectoryUnchanged(path: "/tmp/reclaim_nonexistent_path_xyz")
        guard !result else {
            throw TestRunner.Fail(message: "Expected false for un-indexed path, got true")
        }
    }

    r.test("updateDirectoryCache stores size and count and retrieves them") {
        let db = try Database(path: ":memory:")
        let testPath = "/tmp" // directory guaranteed to exist for stat check
        var st = stat()
        _ = lstat(testPath, &st)
        let liveMtime = Double(st.st_mtimespec.tv_sec) + Double(st.st_mtimespec.tv_nsec) / 1_000_000_000

        db.updateDirectoryCache(for: testPath, mtime: liveMtime, allocatedBytes: 1048576, fileCount: 42)
        let stats = db.cachedDirectoryStats(for: testPath)
        guard let stats = stats else {
            throw TestRunner.Fail(message: "Expected non-nil cached stats for unchanged directory")
        }
        try r.expectEqual(stats.allocatedBytes, 1048576)
        try r.expectEqual(stats.fileCount, 42)
    }

    r.test("invalidateCache removes parent and child directory cache entries") {
        let db = try Database(path: ":memory:")
        let parentPath = "/Users/test/.npm"
        let childPath = "/Users/test/.npm/_cacache/content"
        let unrelatedPath = "/Users/test/.gradle"

        db.updateDirectoryCache(for: parentPath, mtime: 12345.0, allocatedBytes: 5_000_000_000, fileCount: 100)
        db.updateDirectoryCache(for: unrelatedPath, mtime: 12345.0, allocatedBytes: 2_000_000_000, fileCount: 50)

        // Invalidating a child path should invalidate the parent cache entry
        db.invalidateCache(for: childPath)
        try r.expectEqual(db.cachedMtime(for: parentPath) == nil, true)
        // Unrelated path remains intact
        try r.expectEqual(db.cachedMtime(for: unrelatedPath) != nil, true)

        // Invalidating the unrelated path explicitly removes it
        db.invalidateCache(for: unrelatedPath)
        try r.expectEqual(db.cachedMtime(for: unrelatedPath) == nil, true)
    }

    r.test("clearDirectoryCache clears all cached entries") {
        let db = try Database(path: ":memory:")
        db.updateDirectoryCache(for: "/path1", mtime: 100, allocatedBytes: 100, fileCount: 1)
        db.updateDirectoryCache(for: "/path2", mtime: 200, allocatedBytes: 200, fileCount: 2)

        try r.expectEqual(try db.queryInt("SELECT COUNT(*) FROM directory_cache"), 2)
        db.clearDirectoryCache()
        try r.expectEqual(try db.queryInt("SELECT COUNT(*) FROM directory_cache"), 0)
    }
}


