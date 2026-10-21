// AnalyzerTests.swift
// ReclaimTests

import Foundation
@testable import Reclaim

func runAnalyzerTests(_ r: TestRunner) async {
    print("\nAnalyzers")

    let context = AnalysisContext(rootURL: URL(fileURLWithPath: "/tmp"))

    // MARK: - GradleAnalyzer
    await r.asyncTest("GradleAnalyzer correctly classifies root vs caches vs wrapper vs daemon") {
        let analyzer = GradleAnalyzer()

        // Root .gradle must be HIGH risk, not cleanup candidate
        let rootItem = StorageItem(path: "/Users/test/.gradle", logicalSize: 1000, allocatedSize: 4096)
        try r.expect(analyzer.canAnalyze(rootItem))
        let rootResult = try await analyzer.analyze(item: rootItem, context: context)
        try r.expectEqual(rootResult.item.risk, .high)
        try r.expect(!rootResult.isCleanupCandidate)

        // Caches must be LOW risk, regeneratable, cleanup candidate
        let cacheItem = StorageItem(path: "/Users/test/.gradle/caches/modules-2", logicalSize: 5000, allocatedSize: 8192)
        let cacheResult = try await analyzer.analyze(item: cacheItem, context: context)
        try r.expectEqual(cacheResult.item.risk, .low)
        try r.expectEqual(cacheResult.item.recoverability, .regeneratable)
        try r.expect(cacheResult.isCleanupCandidate)

        // Wrapper dists
        let wrapperItem = StorageItem(path: "/Users/test/.gradle/wrapper/dists/gradle-8.0", logicalSize: 10000, allocatedSize: 16384)
        let wrapperResult = try await analyzer.analyze(item: wrapperItem, context: context)
        try r.expectEqual(wrapperResult.item.risk, .low)
        try r.expectEqual(wrapperResult.item.recoverability, .redownloadable)
        try r.expect(wrapperResult.isCleanupCandidate)

        // Daemon logs
        let daemonItem = StorageItem(path: "/Users/test/.gradle/daemon/8.0", logicalSize: 200, allocatedSize: 4096)
        let daemonResult = try await analyzer.analyze(item: daemonItem, context: context)
        try r.expectEqual(daemonResult.item.risk, .safe)
        try r.expect(daemonResult.isCleanupCandidate)
    }

    // MARK: - NodeAnalyzer
    await r.asyncTest("NodeAnalyzer detects lockfile for node_modules") {
        let analyzer = NodeAnalyzer()

        // Path with lockfile in fixture
        let currentDir = FileManager.default.currentDirectoryPath
        let projectWithLock = "\(currentDir)/Tests/Fixtures/node/project-with-lockfile/node_modules"
        let itemWithLock = StorageItem(path: projectWithLock, logicalSize: 2000, allocatedSize: 4096)
        try r.expect(analyzer.canAnalyze(itemWithLock))

        let resultWithLock = try await analyzer.analyze(item: itemWithLock, context: context)
        try r.expectEqual(resultWithLock.item.risk, .low)
        try r.expectEqual(resultWithLock.item.recoverability, .rebuildable)
        try r.expect(resultWithLock.isCleanupCandidate)

        // Path without lockfile
        let projectWithoutLock = "\(currentDir)/Tests/Fixtures/node/project-without-lockfile/node_modules"
        let itemWithoutLock = StorageItem(path: projectWithoutLock, logicalSize: 2000, allocatedSize: 4096)
        let resultWithoutLock = try await analyzer.analyze(item: itemWithoutLock, context: context)
        try r.expectEqual(resultWithoutLock.item.risk, .medium)
        try r.expect(!resultWithoutLock.isCleanupCandidate)

        // Global package cache
        let npmCacheItem = StorageItem(path: "/Users/test/.npm/_cacache", logicalSize: 5000, allocatedSize: 8192)
        let npmResult = try await analyzer.analyze(item: npmCacheItem, context: context)
        try r.expectEqual(npmResult.item.risk, .safe)
        try r.expectEqual(npmResult.item.recoverability, .redownloadable)
        try r.expect(npmResult.isCleanupCandidate)
    }

    // MARK: - HomebrewAnalyzer
    await r.asyncTest("HomebrewAnalyzer classifies downloads cache vs Cellar formula") {
        let analyzer = HomebrewAnalyzer()

        let downloadItem = StorageItem(path: "/Users/test/Library/Caches/Homebrew/downloads/pkg.tar.gz", logicalSize: 5000, allocatedSize: 8192)
        try r.expect(analyzer.canAnalyze(downloadItem))
        let downloadResult = try await analyzer.analyze(item: downloadItem, context: context)
        try r.expectEqual(downloadResult.item.risk, .safe)
        try r.expectEqual(downloadResult.item.recoverability, .redownloadable)
        try r.expect(downloadResult.isCleanupCandidate)

        let cellarItem = StorageItem(path: "/opt/homebrew/Cellar/wget/1.21.3", logicalSize: 2000, allocatedSize: 4096)
        let cellarResult = try await analyzer.analyze(item: cellarItem, context: context)
        try r.expectEqual(cellarResult.item.risk, .low)
        try r.expect(cellarResult.isCleanupCandidate)
    }

    // MARK: - DockerAnalyzer
    await r.asyncTest("DockerAnalyzer isolates persistent volumes from build cache") {
        let analyzer = DockerAnalyzer()

        // Volumes must be HIGH risk and NOT a cleanup candidate
        let volumeItem = StorageItem(path: "/Users/test/Library/Containers/com.docker.docker/Data/volumes/db_data", logicalSize: 10000, allocatedSize: 16384)
        try r.expect(analyzer.canAnalyze(volumeItem))
        let volumeResult = try await analyzer.analyze(item: volumeItem, context: context)
        try r.expectEqual(volumeResult.item.risk, .high)
        try r.expectEqual(volumeResult.item.recoverability, .userData)
        try r.expect(!volumeResult.isCleanupCandidate)

        // Buildkit cache is SAFE
        let buildCacheItem = StorageItem(path: "/Users/test/docker/buildkit-cache", logicalSize: 5000, allocatedSize: 8192)
        let buildCacheResult = try await analyzer.analyze(item: buildCacheItem, context: context)
        try r.expectEqual(buildCacheResult.item.risk, .safe)
        try r.expect(buildCacheResult.isCleanupCandidate)

        // Docker.raw is HIGH risk
        let rawItem = StorageItem(path: "/Users/test/Docker.raw", logicalSize: 50000, allocatedSize: 65536)
        let rawResult = try await analyzer.analyze(item: rawItem, context: context)
        try r.expectEqual(rawResult.item.risk, .high)
        try r.expect(!rawResult.isCleanupCandidate)
    }

    // MARK: - XcodeAnalyzer
    await r.asyncTest("XcodeAnalyzer separates DerivedData, Archives, DeviceSupport, and Simulators") {
        let analyzer = XcodeAnalyzer()

        // DerivedData -> SAFE, rebuildable
        let ddItem = StorageItem(path: "/Users/test/Library/Developer/Xcode/DerivedData/Project-xyz", logicalSize: 10000, allocatedSize: 16384)
        try r.expect(analyzer.canAnalyze(ddItem))
        let ddResult = try await analyzer.analyze(item: ddItem, context: context)
        try r.expectEqual(ddResult.item.risk, .safe)
        try r.expectEqual(ddResult.item.recoverability, .rebuildable)
        try r.expect(ddResult.isCleanupCandidate)

        // Archive -> MEDIUM risk, review required
        let archiveItem = StorageItem(path: "/Users/test/Library/Developer/Xcode/Archives/2024-01-01/App.xcarchive", logicalSize: 15000, allocatedSize: 20480)
        let archiveResult = try await analyzer.analyze(item: archiveItem, context: context)
        try r.expectEqual(archiveResult.item.risk, .medium)
        try r.expect(!archiveResult.isCleanupCandidate)

        // DeviceSupport -> LOW risk, redownloadable
        let dsItem = StorageItem(path: "/Users/test/Library/Developer/Xcode/iOS DeviceSupport/17.0", logicalSize: 8000, allocatedSize: 12288)
        let dsResult = try await analyzer.analyze(item: dsItem, context: context)
        try r.expectEqual(dsResult.item.risk, .low)
        try r.expectEqual(dsResult.item.recoverability, .redownloadable)
        try r.expect(dsResult.isCleanupCandidate)

        // Simulator Runtime -> LOW risk, redownloadable
        let simItem = StorageItem(path: "/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 17.0.simruntime", logicalSize: 30000, allocatedSize: 32768)
        let simResult = try await analyzer.analyze(item: simItem, context: context)
        try r.expectEqual(simResult.item.risk, .low)
        try r.expectEqual(simResult.item.recoverability, .redownloadable)
        try r.expect(simResult.isCleanupCandidate)
    }
}
