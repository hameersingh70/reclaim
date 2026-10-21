// SystemPressureDiagnosticsTests.swift
// Tests/ReclaimTests/Unit
//
// Unit tests for SystemPressureDiagnostics, MemoryMetrics, and LightweightSentinelMonitor.

import Foundation
import Reclaim

final class TestBox: @unchecked Sendable {
    var value: Bool = false
}

func runSystemPressureDiagnosticsTests(_ runner: TestRunner) async {
    runner.test("MemoryMetrics calculates formatted strings and active swap correctly") {
        let metrics = MemoryMetrics(
            totalPhysicalRAM: 16 * 1024 * 1024 * 1024,
            usedRAM: 12 * 1024 * 1024 * 1024,
            freeRAM: 4 * 1024 * 1024 * 1024,
            activeRAM: 6 * 1024 * 1024 * 1024,
            inactiveRAM: 3 * 1024 * 1024 * 1024,
            wiredRAM: 3 * 1024 * 1024 * 1024,
            compressedRAM: 2 * 1024 * 1024 * 1024,
            swapUsed: 4 * 1024 * 1024 * 1024,
            swapTotal: 8 * 1024 * 1024 * 1024,
            pressurePercentage: 75.0
        )

        try runner.expect(metrics.isSwapActive, "Swap should be reported active when 4GB used")
        try runner.expect(!metrics.formattedUsedRAM.isEmpty)
        try runner.expect(!metrics.formattedSwapUsed.isEmpty)
        try runner.expectEqual(metrics.pressurePercentage, 75.0)
    }

    runner.test("SystemPressureDiagnostics reads valid positive Mach VM memory metrics") {
        let diagnostics = SystemPressureDiagnostics()
        let metrics = diagnostics.readMemoryMetrics()

        try runner.expect(metrics.totalPhysicalRAM > 0, "Physical RAM must be positive")
        try runner.expect(metrics.usedRAM >= 0, "Used RAM must be non-negative")
        try runner.expect(metrics.freeRAM >= 0, "Free RAM must be non-negative")
        try runner.expect(metrics.pressurePercentage >= 0.0 && metrics.pressurePercentage <= 100.0, "Pressure must be 0..100")
    }

    await runner.asyncTest("SystemPressureDiagnostics generates complete pressure report") {
        let diagnostics = SystemPressureDiagnostics()
        let report = await diagnostics.generateReport()

        try runner.expect(!report.summary.isEmpty, "Report summary must not be empty")
        try runner.expect(report.metrics.totalPhysicalRAM > 0)
        try runner.expect(!report.recommendations.isEmpty, "Report should contain recommendations")
    }

    await runner.asyncTest("SystemPressureDiagnostics inspectProcesses parses and ranks memory consumers") {
        let diagnostics = SystemPressureDiagnostics()
        let processes = await diagnostics.inspectProcesses(limit: 5)

        if !processes.isEmpty {
            try runner.expect(processes.first!.memoryBytes >= processes.last!.memoryBytes, "Processes must be sorted descending by memory")
            try runner.expect(processes.first!.pid > 0)
        }
    }

    await runner.asyncTest("LightweightSentinelMonitor can initialize and evaluate pressure") {
        let monitor = LightweightSentinelMonitor()
        let box = TestBox()

        monitor.onPressureChanged = { report in
            box.value = true
        }

        await monitor.evaluateSystemPressure(reason: "Unit Test")
        try runner.expect(box.value, "Sentinel callback must be invoked on evaluation")
    }
}
