// PerformanceTests.swift
// ReclaimTests
//
// Performance benchmark testing throughput on synthetic directory trees per PRD §30.

import Foundation
@testable import Reclaim

func runPerformanceTests(_ r: TestRunner) async {
    print("\nBenchmarks")

    await r.asyncTest("Benchmark scanner on 500 synthetic files in temp directory") {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ReclaimBenchmark-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create 500 synthetic files across 10 subdirectories
        for dirIndex in 0..<10 {
            let subDir = tempDir.appendingPathComponent("dir_\(dirIndex)")
            try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
            for fileIndex in 0..<50 {
                let fileURL = subDir.appendingPathComponent("file_\(fileIndex).txt")
                try "synthetic data \(fileIndex)".write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }

        let startTime = Date()
        let scanner = FileScanner(rootURL: tempDir)
        var count = 0
        for await _ in scanner.scan() {
            count += 1
        }
        let elapsed = Date().timeIntervalSince(startTime)

        try r.expect(count >= 500, "Should scan at least 500 files, scanned: \(count)")
        try r.expect(elapsed < 3.0, "Scanning 500 files should take under 3.0s, took: \(String(format: "%.3f", elapsed))s")
    }
}
