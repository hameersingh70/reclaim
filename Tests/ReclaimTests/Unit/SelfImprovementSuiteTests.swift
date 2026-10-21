// SelfImprovementSuiteTests.swift
// Tests/Unit
//
// Tests for App Uninstaller, Orphan Leftovers, System Maintenance,
// Persistent Receipts querying, and Large File kind/age filtering.

import Foundation
import Reclaim

func registerSelfImprovementSuiteTests(in r: TestRunner) {

    // MARK: - App Uninstaller Tests

    r.test("AppUninstallerScanner detects app leftovers across Library folders") {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let appsDir = tempDir.appendingPathComponent("Applications")
        let libraryDir = tempDir.appendingPathComponent("Library")
        let appSupportDir = libraryDir.appendingPathComponent("Application Support/AcmeApp")
        let cachesDir = libraryDir.appendingPathComponent("Caches/com.acme.app")
        let prefFile = libraryDir.appendingPathComponent("Preferences/com.acme.app.plist")

        try FileManager.default.createDirectory(at: appsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cachesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: prefFile.deletingLastPathComponent(), withIntermediateDirectories: true)

        try Data("dummy support".utf8).write(to: appSupportDir.appendingPathComponent("data.db"))
        try Data("dummy cache".utf8).write(to: cachesDir.appendingPathComponent("cache.bin"))
        try Data("dummy plist".utf8).write(to: prefFile)

        defer { try? FileManager.default.removeItem(at: tempDir) }

        let scanner = AppUninstallerScanner(homeURL: tempDir)
        let leftovers = scanner.findLeftovers(forAppName: "AcmeApp", bundleIdentifier: "com.acme.app")

        try r.expect(leftovers.count >= 3, "Should detect at least 3 leftover items (AppSupport, Caches, Preferences)")
        let categories = Set(leftovers.map(\.category))
        try r.expect(categories.contains(.applicationSupport), "Must find Application Support leftover")
        try r.expect(categories.contains(.caches), "Must find Caches leftover")
        try r.expect(categories.contains(.preferences), "Must find Preferences leftover")
    }

    r.test("AppUninstallerScanner discovers orphaned leftovers for deleted apps") {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let libraryDir = tempDir.appendingPathComponent("Library")
        let orphanAppSupport = libraryDir.appendingPathComponent("Application Support/OldDeletedApp")

        try FileManager.default.createDirectory(at: orphanAppSupport, withIntermediateDirectories: true)
        // Write a 2MB file so it passes the minimum size threshold
        let dummyData = Data(count: 2 * 1024 * 1024)
        try dummyData.write(to: orphanAppSupport.appendingPathComponent("heavy_cache.db"))

        defer { try? FileManager.default.removeItem(at: tempDir) }

        let scanner = AppUninstallerScanner(homeURL: tempDir)
        let orphans = scanner.scanOrphanLeftovers(knownApps: [])

        try r.expect(!orphans.isEmpty, "Should find at least 1 orphan app leftover")
        let first = orphans.first { $0.name.lowercased().contains("olddeletedapp") }
        try r.expect(first != nil, "Must identify OldDeletedApp as an orphan")
        try r.expect(first?.isOrphan == true, "Must have isOrphan = true")
        try r.expect(first?.totalSize ?? 0 > 1_000_000, "Must calculate size over 1MB")
    }

    // MARK: - Database fetchReceipts Tests

    r.test("Database fetchReceipts returns saved receipts ordered by date descending") {
        let db = try Database(path: ":memory:")
        let r1 = CleanupReceipt(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-100),
            beforeAvailableBytes: 10_000,
            afterAvailableBytes: 20_000,
            actualRecoveredBytes: 10_000,
            actions: [CleanupActionSummary(path: "/tmp/a", description: "a", reclaimedBytes: 10_000, success: true)]
        )
        let r2 = CleanupReceipt(
            id: UUID(),
            timestamp: Date(),
            beforeAvailableBytes: 20_000,
            afterAvailableBytes: 50_000,
            actualRecoveredBytes: 30_000,
            actions: [CleanupActionSummary(path: "/tmp/b", description: "b", reclaimedBytes: 30_000, success: true)]
        )

        try db.save(receipt: r1)
        try db.save(receipt: r2)

        let fetched = db.fetchReceipts(limit: 10)
        try r.expectEqual(fetched.count, 2, "Should fetch 2 receipts")
        try r.expectEqual(fetched[0].id, r2.id, "First fetched must be latest receipt (r2)")
        try r.expectEqual(fetched[1].id, r1.id, "Second fetched must be older receipt (r1)")
        try r.expectEqual(fetched[0].actualRecoveredBytes, 30_000)
    }

    // MARK: - FileKindFilter Tests

    r.test("FileKindFilter accurately identifies file types") {
        try r.expect(FileKindFilter.archives.matches(path: "/Downloads/xcode.dmg"))
        try r.expect(FileKindFilter.archives.matches(path: "/Downloads/sources.tar.gz"))
        try r.expect(FileKindFilter.archives.matches(path: "/Downloads/project.zip"))

        try r.expect(FileKindFilter.media.matches(path: "/Movies/screencast.mov"))
        try r.expect(FileKindFilter.media.matches(path: "/Movies/recording.mp4"))

        try r.expect(FileKindFilter.documents.matches(path: "/Documents/contract.pdf"))
        try r.expect(FileKindFilter.documents.matches(path: "/Documents/sheet.xlsx"))

        try r.expect(!FileKindFilter.documents.matches(path: "/Downloads/app.dmg"))
    }

    // MARK: - FileShredderEngine Tests

    r.test("FileShredderEngine shreds file with random bytes and removes it") {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let secretFile = tempDir.appendingPathComponent("api_secret.key")
        let secretContent = "sk-ant-api-key-very-sensitive-data-1234567890"
        try Data(secretContent.utf8).write(to: secretFile)

        let shredder = FileShredderEngine()
        let receipt = try shredder.shred(path: secretFile.path, passes: 1)

        try r.expect(!FileManager.default.fileExists(atPath: secretFile.path), "File must be removed after shredding")
        try r.expect(receipt.bytesShredded > 0, "Receipt must record overwritten bytes")
        try r.expect(receipt.success, "Receipt must report success")
    }

    r.test("FileShredderEngine strictly rejects shredding protected system paths") {
        let shredder = FileShredderEngine()
        var didCatch = false
        do {
            _ = try shredder.shred(path: "/System/Library")
        } catch {
            didCatch = true
            let nsErr = error as NSError
            try r.expectEqual(nsErr.domain, "ReclaimSafety")
        }
        try r.expect(didCatch, "Must throw safety exception when attempting to shred /System/Library")
    }

    // MARK: - Rust & SwiftPM Project Workspace Tests

    r.test("ProjectWorkspaceScanner discovers Rust target directory when Cargo.toml exists") {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let projectDir = tempDir.appendingPathComponent("rust-service")
        let targetDir = projectDir.appendingPathComponent("target")
        let debugDir = targetDir.appendingPathComponent("debug")

        try FileManager.default.createDirectory(at: debugDir, withIntermediateDirectories: true)
        try Data("[package]\nname = \"rust-service\"\nversion = \"0.1.0\"".utf8).write(to: projectDir.appendingPathComponent("Cargo.toml"))
        try Data("# Cargo lock".utf8).write(to: projectDir.appendingPathComponent("Cargo.lock"))
        try Data(count: 64 * 1024).write(to: debugDir.appendingPathComponent("binary.o"))

        defer { try? FileManager.default.removeItem(at: tempDir) }

        let items = ProjectWorkspaceScanner.scanWorkspaces(roots: [tempDir], scanRust: true)
        try r.expect(!items.isEmpty, "Should discover Rust target directory")
        let rustItem = items.first { $0.category == .rust }
        try r.expect(rustItem != nil, "Discovered item must have category .rust")
        try r.expect(rustItem?.risk == .low, "Rust project with Cargo.lock must have .low risk")
        try r.expect(rustItem?.whatIsThis?.contains("Rust Build Artifacts") == true)
    }

    r.test("ProjectWorkspaceScanner discovers SwiftPM .build directory when Package.swift exists") {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let projectDir = tempDir.appendingPathComponent("swift-cli")
        let buildDir = projectDir.appendingPathComponent(".build")
        let x86Dir = buildDir.appendingPathComponent("debug")

        try FileManager.default.createDirectory(at: x86Dir, withIntermediateDirectories: true)
        try Data("// swift-tools-version: 5.9\nimport PackageDescription\n".utf8).write(to: projectDir.appendingPathComponent("Package.swift"))
        try Data(count: 32 * 1024).write(to: x86Dir.appendingPathComponent("SwiftCLI.o"))

        defer { try? FileManager.default.removeItem(at: tempDir) }

        let items = ProjectWorkspaceScanner.scanWorkspaces(roots: [tempDir], scanSwift: true)
        try r.expect(!items.isEmpty, "Should discover SwiftPM .build directory")
        let swiftItem = items.first { $0.category == .xcode && $0.path.contains(".build") }
        try r.expect(swiftItem != nil, "Discovered item must have category .xcode")
        try r.expect(swiftItem?.whatIsThis?.contains("SwiftPM Build Products") == true)
    }

    // MARK: - Advanced Maintenance Tasks Tests

    r.test("SystemMaintenanceEngine defines all 9 maintenance tasks with valid metadata") {
        try r.expectEqual(MaintenanceTaskID.allCases.count, 9, "Must have exactly 9 maintenance tasks")
        for task in MaintenanceTaskID.allCases {
            try r.expect(!task.title.isEmpty, "Task \(task.rawValue) must have non-empty title")
            try r.expect(!task.subtitle.isEmpty, "Task \(task.rawValue) must have non-empty subtitle")
            try r.expect(!task.iconName.isEmpty, "Task \(task.rawValue) must have non-empty iconName")
        }
    }
}
