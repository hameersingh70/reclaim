// SystemStorageTests.swift
// Tests/ReclaimTests/Unit
//
// Unit tests for SystemStorageInspector and Apple-style storage models.

import Foundation
import Reclaim

func runSystemStorageTests(_ r: TestRunner) async {
    print("\nSystemStorageInspector")

    r.test("Volume metrics returns valid positive capacity") {
        let inspector = SystemStorageInspector()
        let metrics = inspector.getVolumeMetrics()
        try r.expect(metrics.total > 0, "Total capacity must be > 0")
        try r.expect(metrics.available >= 0, "Available capacity must be >= 0")
        try r.expect(metrics.used >= 0, "Used capacity must be >= 0")
        try r.expect(!metrics.name.isEmpty, "Volume name must not be empty")
    }

    r.test("Fast folder sizing returns 0 for non-existent path") {
        let inspector = SystemStorageInspector()
        let size = inspector.fastFolderSize(at: URL(fileURLWithPath: "/non/existent/path/for/sure/12345"))
        try r.expectEqual(size, 0)
    }

    r.test("Fast folder sizing calculates synthetic directory size correctly") {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file1 = tempDir.appendingPathComponent("file1.bin")
        let file2 = tempDir.appendingPathComponent("file2.bin")
        let data1 = Data(repeating: 0xAA, count: 1024)
        let data2 = Data(repeating: 0xBB, count: 2048)

        try data1.write(to: file1)
        try data2.write(to: file2)

        let inspector = SystemStorageInspector()
        let size = inspector.fastFolderSize(at: tempDir)
        try r.expect(size >= 3072, "Size must be at least total written bytes: got \(size)")
    }

    r.test("Overview ratio and formatting helpers") {
        let overview = SystemStorageOverview(
            volumeName: "Macintosh HD",
            totalCapacityBytes: 200_000_000_000,
            availableCapacityBytes: 50_000_000_000,
            usedCapacityBytes: 150_000_000_000,
            categories: []
        )

        try r.expectEqual(overview.usedRatio, 0.75)
        try r.expectEqual(overview.availableRatio, 0.25)
        try r.expect(!overview.formattedTotal.isEmpty)
        try r.expect(!overview.formattedAvailable.isEmpty)
        try r.expect(!overview.formattedUsed.isEmpty)
    }

    r.test("SystemStorageCategoryAllocation properties") {
        let cat = SystemStorageCategoryAllocation(
            id: "dev",
            name: "Developer",
            categoryType: .developer,
            allocatedBytes: 10_000_000_000,
            contributingPaths: ["/Users/test/Library/Developer"],
            iconName: "hammer.fill",
            badgeColorHex: "#51CF66",
            isCleanable: true,
            cleanupActionDescription: "Purge stale build artifacts"
        )

        try r.expectEqual(cat.name, "Developer")
        try r.expectEqual(cat.categoryType, .developer)
        try r.expect(cat.isCleanable)
        try r.expect(!cat.formattedBytes.isEmpty)
    }

    r.test("Security guard prevents deleting items outside .Trash") {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sensitiveFile = tempDir.appendingPathComponent("important.txt")
        try Data("secret".utf8).write(to: sensitiveFile)

        let inspector = SystemStorageInspector()
        var didCatchSecurityError = false
        do {
            try inspector.deleteTrashItem(path: sensitiveFile.path)
        } catch {
            didCatchSecurityError = true
        }

        try r.expect(didCatchSecurityError, "Must reject deleting files outside ~/.Trash")
        try r.expect(FileManager.default.fileExists(atPath: sensitiveFile.path), "Sensitive file must not have been deleted")
    }

    await r.asyncTest("Inspect overview completes asynchronously and populates standard categories") {
        let inspector = SystemStorageInspector()
        let overview = await inspector.inspectOverview()
        try r.expect(!overview.categories.isEmpty, "Overview categories must not be empty")
        let categoryTypes = Set(overview.categories.map(\.categoryType))
        try r.expect(categoryTypes.contains(.applications), "Must contain Applications")
        try r.expect(categoryTypes.contains(.developer), "Must contain Developer")
        try r.expect(categoryTypes.contains(.bin), "Must contain Bin")
        try r.expect(categoryTypes.contains(.macOS), "Must contain macOS")
        try r.expect(categoryTypes.contains(.systemData), "Must contain System Data")
    }

    r.test("inspectTrash returns valid items and size") {
        let inspector = SystemStorageInspector()
        let (bytes, items) = inspector.inspectTrash()
        print("DEBUG: inspectTrash returned \(bytes) bytes, \(items.count) items")
        try r.expect(bytes >= 0, "Trash bytes must be >= 0")
        try r.expect(items.count >= 0, "Trash item count must be >= 0")
    }

    r.test("Developer toolchains incorporates scanned items") {
        let inspector = SystemStorageInspector()
        let dummyItem = StorageItem(
            path: "/Users/test/Library/Developer/Xcode/DerivedData/ProjectX",
            logicalSize: 500_000_000,
            allocatedSize: 500_000_000,
            category: .xcode,
            risk: .safe,
            recoverability: .regeneratable
        )
        let (baseBytes, _) = inspector.inspectDeveloperToolchains()
        let (mergedBytes, mergedItems) = inspector.inspectDeveloperToolchains(extraScanItems: [dummyItem])
        try r.expect(mergedBytes >= baseBytes + 500_000_000, "Merged bytes must incorporate extraScanItems")
        try r.expect(mergedItems.contains(where: { $0.path == dummyItem.path }), "Merged items must contain scanned item")
    }

    await r.asyncTest("Inspect overview integrates scanned items") {
        let inspector = SystemStorageInspector()
        let dummyItem = StorageItem(
            path: "/Users/test/.docker/buildx/cache",
            logicalSize: 800_000_000,
            allocatedSize: 800_000_000,
            category: .docker,
            risk: .safe,
            recoverability: .regeneratable
        )
        let overview = await inspector.inspectOverview(scannedItems: [dummyItem])
        let devCat = overview.categories.first { $0.categoryType == .developer }
        try r.expect(devCat != nil, "Developer category must exist")
        try r.expect((devCat?.allocatedBytes ?? 0) >= 800_000_000, "Developer allocation must include scanned items")
    }

    r.test("inspectApplicationCaches classifies caches into running and closed") {
        let inspector = SystemStorageInspector()
        let (running, closed) = inspector.inspectApplicationCaches()
        print("DEBUG: inspectApplicationCaches found \(running.count) running app caches, \(closed.count) closed app caches")
        for item in running {
            try r.expect(item.isRunning, "Item in running list must have isRunning = true")
            try r.expect(item.allocatedBytes > 0, "Item must have positive allocated size")
            try r.expect(!item.appName.isEmpty, "App name must not be empty")
        }
        for item in closed {
            try r.expect(!item.isRunning, "Item in closed list must have isRunning = false")
        }
    }

    r.test("cleanUserCachesWithDetails default safely preserves running apps on fixtures") {
        let tempHome = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cachesDir = tempHome.appendingPathComponent("Library/Caches")
        let closedMock = cachesDir.appendingPathComponent("com.sample.closedapp")
        let runningMock = cachesDir.appendingPathComponent("Google")
        try FileManager.default.createDirectory(at: closedMock, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: runningMock, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempHome) }

        try Data("cache1".utf8).write(to: closedMock.appendingPathComponent("data.bin"))
        try Data("cache2".utf8).write(to: runningMock.appendingPathComponent("data.bin"))

        let inspector = SystemStorageInspector(homeURL: tempHome)
        let (runningBefore, closedBefore) = inspector.inspectApplicationCaches()
        try r.expect(runningBefore.contains(where: { $0.appName.contains("Google") || $0.cacheFolderPath.contains("Google") }))
        try r.expect(closedBefore.contains(where: { $0.cacheFolderPath.contains("com.sample.closedapp") }))

        let result = try inspector.cleanUserCachesWithDetails(includeRunningApps: false)
        try r.expect(result.skippedRunningApps.count > 0, "Must skip running app cache")
        try r.expect(FileManager.default.fileExists(atPath: runningMock.path), "Running app cache folder must remain intact")
        try r.expect(!FileManager.default.fileExists(atPath: closedMock.path), "Closed app cache folder must be removed")
    }

    r.test("getInitialOverview initializes bin category properly") {
        let inspector = SystemStorageInspector()
        let initial = inspector.getInitialOverview()
        let binCat = initial.categories.first { $0.categoryType == .bin }
        try r.expect(binCat != nil, "Bin category must exist in initial overview")
        let (actualTrashBytes, _) = inspector.inspectTrash()
        try r.expectEqual(binCat?.allocatedBytes, actualTrashBytes, "Initial bin bytes must match inspectTrash total bytes")
    }

    r.test("inspectApplications returns real heterogeneous application bundle sizes") {
        let inspector = SystemStorageInspector()
        let (totalBytes, items) = inspector.inspectApplications()
        try r.expect(totalBytes > 0, "Total applications bytes must be positive")
        try r.expect(!items.isEmpty, "Applications items list must not be empty")
        let sizes = Set(items.map(\.allocatedBytes))
        try r.expect(sizes.count > 1, "Applications must have real differing sizes, not a single identical placeholder")
        print("DEBUG: top 5 apps:")
        for app in items.prefix(5) {
            print("  - \(app.name): \(ByteCountFormatter.string(fromByteCount: app.allocatedBytes, countStyle: .file))")
        }
    }
}

