// SafetyEngineTests.swift
// ReclaimTests

import Foundation
@testable import Reclaim

func runSafetyEngineTests(_ r: TestRunner) {
    print("\nSafetyEngine")
    let engine = SafetyEngine()

    r.test("Protects system paths (/System, /bin, /usr/bin)") {
        let systemItem = StorageItem(path: "/System/Library/CoreServices", logicalSize: 100, allocatedSize: 100, risk: .safe)
        let assessed = engine.enforceSafety(on: systemItem)
        try r.expectEqual(assessed.risk, .protected)
        try r.expect(engine.isProtected(path: "/bin/sh"))
        try r.expect(engine.isProtected(path: "/usr/bin/swift"))
    }

    r.test("Protects developer credentials (.ssh, .aws, .gnupg, .kube, .m2/settings.xml)") {
        let sshKey = StorageItem(path: "/Users/test/.ssh/id_rsa", logicalSize: 2048, allocatedSize: 4096, risk: .safe)
        try r.expectEqual(engine.enforceSafety(on: sshKey).risk, .protected)

        let awsCreds = StorageItem(path: "/Users/test/.aws/credentials", logicalSize: 500, allocatedSize: 4096, risk: .safe)
        try r.expectEqual(engine.enforceSafety(on: awsCreds).risk, .protected)

        let m2Settings = StorageItem(path: "/Users/test/.m2/settings.xml", logicalSize: 1000, allocatedSize: 4096, risk: .safe)
        try r.expectEqual(engine.enforceSafety(on: m2Settings).risk, .protected)

        let dockerConfig = StorageItem(path: "/Users/test/.docker/config.json", logicalSize: 200, allocatedSize: 4096, risk: .safe)
        try r.expectEqual(engine.enforceSafety(on: dockerConfig).risk, .protected)
    }

    r.test("User documents and desktop files cannot be auto-cleanup (.high risk)") {
        let doc = StorageItem(path: "/Users/test/Documents/report.docx", logicalSize: 1000, allocatedSize: 4096, risk: .safe)
        let assessedDoc = engine.enforceSafety(on: doc)
        try r.expectEqual(assessedDoc.risk, .high)

        let desktopFile = StorageItem(path: "/Users/test/Desktop/draft.txt", logicalSize: 1000, allocatedSize: 4096, risk: .low)
        let assessedDesktop = engine.enforceSafety(on: desktopFile)
        try r.expectEqual(assessedDesktop.risk, .high)
    }

    r.test("Normal caches pass through without being blocked") {
        let cache = StorageItem(path: "/Users/test/.gradle/caches/modules-2", logicalSize: 5000, allocatedSize: 8192, risk: .safe)
        let assessedCache = engine.enforceSafety(on: cache)
        try r.expectEqual(assessedCache.risk, .safe)
    }

    r.test("assess(result:) revokes cleanup candidate for protected items") {
        let sshItem = StorageItem(path: "/Users/test/.ssh/id_ed25519", logicalSize: 100, allocatedSize: 100, risk: .safe)
        let result = AnalysisResult(item: sshItem, evidence: [], isCleanupCandidate: true)
        let safeResult = engine.assess(result: result)
        try r.expectEqual(safeResult.item.risk, .protected)
        try r.expect(!safeResult.isCleanupCandidate)
        try r.expect(safeResult.rejectionReason != nil)
    }
}
