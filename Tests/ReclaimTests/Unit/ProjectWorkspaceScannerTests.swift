// ProjectWorkspaceScannerTests.swift
// Tests/Unit
//
// Tests for workspace crawling and atomic discovery of project-level
// `node_modules` and Python virtual environments (`.venv`, `venv`).

import Foundation
import Reclaim

func registerProjectWorkspaceScannerTests(in r: TestRunner) {

    r.test("ProjectWorkspaceScanner discovers project node_modules with lockfile") {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let projectDir = tempDir.appendingPathComponent("my-app")
        let nodeModulesDir = projectDir.appendingPathComponent("node_modules")
        let pkgDir = nodeModulesDir.appendingPathComponent("lodash")
        
        try FileManager.default.createDirectory(at: pkgDir, withIntermediateDirectories: true)
        try Data("console.log(1)".utf8).write(to: pkgDir.appendingPathComponent("index.js"))
        try Data("{}".utf8).write(to: projectDir.appendingPathComponent("package.json"))
        try Data("{}".utf8).write(to: projectDir.appendingPathComponent("package-lock.json"))
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let discovered = ProjectWorkspaceScanner.scanWorkspaces(
            roots: [tempDir],
            scanNode: true,
            scanPython: false,
            maxDepth: 3
        )

        try r.expect(discovered.count == 1, "Should discover exactly 1 node_modules folder")
        let item = discovered[0]
        try r.expectEqual(
            URL(fileURLWithPath: item.path).resolvingSymlinksInPath().path,
            nodeModulesDir.resolvingSymlinksInPath().path,
            "Path must match node_modules path"
        )
        try r.expect(item.category == .node, "Category must be .node")
        try r.expect(item.risk == .low, "With lockfile, risk should be .low")
        try r.expect(item.recoverability == .rebuildable, "Must be rebuildable")
        try r.expect(item.allocatedSize > 0, "Allocated size must be positive")
    }

    r.test("ProjectWorkspaceScanner discovers Python virtual environment") {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let projectDir = tempDir.appendingPathComponent("ai-service")
        let venvDir = projectDir.appendingPathComponent(".venv")
        let binDir = venvDir.appendingPathComponent("bin")
        let libDir = venvDir.appendingPathComponent("lib")

        try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: libDir, withIntermediateDirectories: true)
        try Data("home = /usr/bin".utf8).write(to: venvDir.appendingPathComponent("pyvenv.cfg"))
        try Data("echo python".utf8).write(to: binDir.appendingPathComponent("python"))
        try Data("pytest==7.0".utf8).write(to: projectDir.appendingPathComponent("requirements.txt"))
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let discovered = ProjectWorkspaceScanner.scanWorkspaces(
            roots: [tempDir],
            scanNode: false,
            scanPython: true,
            maxDepth: 3
        )

        try r.expect(discovered.count == 1, "Should discover exactly 1 Python venv")
        let item = discovered[0]
        try r.expectEqual(
            URL(fileURLWithPath: item.path).resolvingSymlinksInPath().path,
            venvDir.resolvingSymlinksInPath().path,
            "Path must match .venv path"
        )
        try r.expect(item.category == .pythonEnv, "Category must be .pythonEnv")
        try r.expect(item.risk == .low, "Virtual environment risk should be .low")
        try r.expect(item.recoverability == .rebuildable, "Must be rebuildable")
        try r.expect((item.whatIsThis ?? "").contains(".venv"), "WhatIsThis should describe virtualenv")
    }

    r.test("ProjectWorkspaceScanner ignores plain .env text files") {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let projectDir = tempDir.appendingPathComponent("web-app")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        try Data("DATABASE_URL=postgres://localhost".utf8).write(to: projectDir.appendingPathComponent(".env"))
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let discovered = ProjectWorkspaceScanner.scanWorkspaces(
            roots: [tempDir],
            scanNode: true,
            scanPython: true,
            maxDepth: 3
        )

        try r.expect(discovered.isEmpty, "Plain .env file must NOT be detected as a virtualenv")
    }

    r.test("SafetyEngine preserves .low risk for project node_modules inside Documents") {
        let engine = SafetyEngine()
        let item = StorageItem(
            path: "/Users/test/Documents/GitHub/my-project/node_modules",
            logicalSize: 100_000_000,
            allocatedSize: 100_000_000,
            category: .node,
            risk: .low,
            recoverability: .rebuildable
        )
        let assessed = engine.enforceSafety(on: item)
        try r.expect(assessed.risk == .low, "node_modules inside Documents must remain .low risk, not overridden to .high")
    }
}
