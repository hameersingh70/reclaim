// LightweightSentinelMonitor.swift
// Reclaim Core — System Diagnostics & Pressure Insights
//
// Ultra-lightweight kernel-level memory pressure sentinel.
// Uses Darwin DISPATCH_SOURCE_TYPE_MEMORYPRESSURE to sleep at 0% CPU,
// waking up only when the Mach VM kernel signals memory pressure transitions.

import Foundation
import Dispatch

// MARK: - Sentinel Monitor Delegate

public protocol LightweightSentinelMonitorDelegate: AnyObject, Sendable {
    func sentinelDidDetectPressureChange(report: PressureReport)
    func sentinelDidDetectSlownessAlert(report: PressureReport, message: String)
}

// MARK: - Sentinel Monitor Implementation

public final class LightweightSentinelMonitor: @unchecked Sendable {
    public static let shared = LightweightSentinelMonitor()

    private let diagnostics: SystemPressureDiagnosticsProtocol
    private var pressureSource: (any DispatchSourceMemoryPressure)?
    private var fallbackTimer: (any DispatchSourceTimer)?
    private let queue = DispatchQueue(label: "com.reclaim.sentinel", qos: .utility)

    private var isRunning = false
    private var lastAlertTimestamp: Date?
    private var lastObservedLevel: MemoryPressureLevel = .normal
    private let alertCooldownSeconds: TimeInterval = 1800 // 30 minutes cooldown

    public weak var delegate: LightweightSentinelMonitorDelegate?

    public var onPressureChanged: (@Sendable (PressureReport) -> Void)?
    public var onSlownessDetected: (@Sendable (PressureReport, String) -> Void)?

    public init(diagnostics: SystemPressureDiagnosticsProtocol = SystemPressureDiagnostics()) {
        self.diagnostics = diagnostics
    }

    // MARK: - Lifecycle

    public func start() {
        queue.async { [weak self] in
            guard let self = self, !self.isRunning else { return }
            self.isRunning = true
            self.setupKernelMemoryPressureHook()
            self.setupFallbackTimer()
        }
    }

    public func stop() {
        queue.async { [weak self] in
            guard let self = self, self.isRunning else { return }
            self.isRunning = false
            self.pressureSource?.cancel()
            self.pressureSource = nil
            self.fallbackTimer?.cancel()
            self.fallbackTimer = nil
        }
    }

    // MARK: - Kernel Dispatch Source (0% CPU)

    private func setupKernelMemoryPressureHook() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task {
                await self.evaluateSystemPressure(reason: "Kernel Memory Pressure Event")
            }
        }

        source.resume()
        self.pressureSource = source
    }

    // MARK: - Fallback Timer (Low-frequency 60s)

    private func setupFallbackTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 60, repeating: 60)

        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task {
                await self.evaluateSystemPressure(reason: "Periodic Check")
            }
        }

        timer.resume()
        self.fallbackTimer = timer
    }

    // MARK: - Evaluation & Debouncing

    public func evaluateSystemPressure(reason: String = "Manual") async {
        let report = await diagnostics.generateReport()
        let currentLevel = report.pressureLevel

        // Notify general observer
        onPressureChanged?(report)
        delegate?.sentinelDidDetectPressureChange(report: report)

        // Check if we need to alert the user
        let shouldAlert: Bool
        let now = Date()

        if currentLevel == .critical && lastObservedLevel != .critical {
            // Instant escalation to critical
            shouldAlert = true
        } else if (currentLevel == .warning || currentLevel == .critical) {
            if let last = lastAlertTimestamp {
                shouldAlert = now.timeIntervalSince(last) >= alertCooldownSeconds
            } else {
                shouldAlert = true
            }
        } else {
            shouldAlert = false
        }

        if shouldAlert {
            lastAlertTimestamp = now
            let alertMessage: String
            if currentLevel == .critical {
                alertMessage = "Critical memory pressure: \(report.metrics.formattedSwapUsed) swapped to SSD. Tap to inspect slowness causes."
            } else {
                alertMessage = "Elevated memory pressure (\(Int(report.metrics.pressurePercentage))%). Tap to view insights."
            }

            onSlownessDetected?(report, alertMessage)
            delegate?.sentinelDidDetectSlownessAlert(report: report, message: alertMessage)
        }

        lastObservedLevel = currentLevel
    }
}
