// ExpandedFeaturesSuiteTests.swift
// Tests/ReclaimTests/Unit
//
// Unit tests for expanded developer features:
// Developer macOS Tweaks Engine, LaunchAgents Manager, Duplicate Asset Detector,
// and Low-Disk Sentinel.

import Foundation
import Reclaim

func runExpandedFeaturesSuiteTests(_ r: TestRunner) async {
    print("\nExpanded Developer Features (Tweaks, Daemons, Duplicates, Sentinel)")

    // MARK: - Developer Tweaks

    r.test("DeveloperTweaksEngine catalog is non-empty and well-formed") {
        let tweaks = DeveloperTweaksEngine.standardTweaks
        try r.expect(tweaks.count >= 8)

        let hiddenFilesTweak = tweaks.first { $0.id == "finder.showHiddenFiles" }
        try r.expect(hiddenFilesTweak != nil)
        try r.expect(hiddenFilesTweak?.domain == "com.apple.finder")
        try r.expect(hiddenFilesTweak?.key == "AppleShowAllFiles")

        let xcodeTweak = tweaks.first { $0.id == "xcode.buildDuration" }
        try r.expect(xcodeTweak != nil)
        try r.expect(xcodeTweak?.domain == "com.apple.dt.Xcode")
    }

    r.test("DeveloperTweaksEngine loadTweaks checks current status safely") {
        let engine = DeveloperTweaksEngine()
        let loaded = engine.loadTweaks()
        try r.expect(loaded.count == DeveloperTweaksEngine.standardTweaks.count)
        for item in loaded {
            try r.expect(item.isEnabled == true || item.isEnabled == false)
        }
    }

    // MARK: - LaunchAgents Manager

    r.test("LaunchAgentsManager scans user and system daemons without crashing") {
        let manager = LaunchAgentsManager()
        let items = manager.scan()
        try r.expect(items.count >= 0)

        for item in items {
            try r.expect(!item.id.isEmpty)
            try r.expect(!item.label.isEmpty)
            try r.expect(!item.plistPath.isEmpty)
        }
    }

    // MARK: - Duplicate Asset Detector

    await r.asyncTest("DuplicateAssetDetector identifies identical files via sparse chunk hashing") {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ReclaimDupTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create two identical 500KB files with .bin extension
        let dummyData = Data(repeating: 0x42, count: 512 * 1024)
        let file1 = tempDir.appendingPathComponent("model_v1.bin")
        let file2 = tempDir.appendingPathComponent("model_v1_copy.bin")
        let file3 = tempDir.appendingPathComponent("unique_model.bin")

        try dummyData.write(to: file1)
        try dummyData.write(to: file2)
        // Create a different file of identical size
        var diffData = dummyData
        diffData[0] = 0x99
        try diffData.write(to: file3)

        let detector = DuplicateAssetDetector()
        let groups = await detector.scan(roots: [tempDir], minByteSize: 1000)

        try r.expect(groups.count == 1)
        let group = groups[0]
        try r.expect(group.items.count == 2)
        try r.expect(group.fileSize == 512 * 1024)
        try r.expect(group.potentialSavings == 512 * 1024)
    }

    // MARK: - Low-Disk Sentinel Headroom

    r.test("LightweightSentinelMonitor handles storage headroom threshold") {
        let monitor = LightweightSentinelMonitor.shared
        monitor.lowStorageThresholdBytes = 10 * 1024 * 1024 * 1024 // 10 GB
        try r.expect(monitor.lowStorageThresholdBytes == 10 * 1024 * 1024 * 1024)

        // Calling evaluateStorageHeadroom should not throw or crash
        monitor.evaluateStorageHeadroom()
    }
}
