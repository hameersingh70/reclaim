// PressureModels.swift
// Reclaim Core — System Diagnostics & Pressure Insights
//
// Domain models representing macOS Unified Memory pressure, APFS swap paging,
// AI model residency, and process-level bottleneck insights.

import Foundation

// MARK: - Memory Pressure Level

public enum MemoryPressureLevel: String, Sendable, Codable, CaseIterable {
    case normal = "NORMAL"
    case warning = "WARNING"
    case critical = "CRITICAL"

    public var displayName: String {
        switch self {
        case .normal: return "Optimal"
        case .warning: return "Elevated Pressure"
        case .critical: return "Critical Swap Thrashing"
        }
    }

    public var statusDescription: String {
        switch self {
        case .normal:
            return "System responsiveness is smooth. Adequate unified memory available."
        case .warning:
            return "Unified memory is constrained. APFS swap paging starting to impact responsiveness."
        case .critical:
            return "Heavy swap thrashing detected. SSD bandwidth saturated; high risk of UI stalls."
        }
    }

    public var badgeColorHex: String {
        switch self {
        case .normal: return "#00E5FF" // Cyan
        case .warning: return "#FFD600" // Yellow
        case .critical: return "#FF3B30" // Red
        }
    }
}

// MARK: - Memory Metrics

public struct MemoryMetrics: Sendable, Codable, Equatable {
    public let totalPhysicalRAM: Int64
    public let usedRAM: Int64
    public let freeRAM: Int64
    public let activeRAM: Int64
    public let inactiveRAM: Int64
    public let wiredRAM: Int64
    public let compressedRAM: Int64
    public let swapUsed: Int64
    public let swapTotal: Int64
    public let pressurePercentage: Double

    public init(
        totalPhysicalRAM: Int64,
        usedRAM: Int64,
        freeRAM: Int64,
        activeRAM: Int64,
        inactiveRAM: Int64,
        wiredRAM: Int64,
        compressedRAM: Int64,
        swapUsed: Int64,
        swapTotal: Int64,
        pressurePercentage: Double
    ) {
        self.totalPhysicalRAM = totalPhysicalRAM
        self.usedRAM = usedRAM
        self.freeRAM = freeRAM
        self.activeRAM = activeRAM
        self.inactiveRAM = inactiveRAM
        self.wiredRAM = wiredRAM
        self.compressedRAM = compressedRAM
        self.swapUsed = swapUsed
        self.swapTotal = swapTotal
        self.pressurePercentage = pressurePercentage
    }

    public var formattedUsedRAM: String {
        ByteCountFormatter.string(fromByteCount: usedRAM, countStyle: .memory)
    }

    public var formattedTotalRAM: String {
        ByteCountFormatter.string(fromByteCount: totalPhysicalRAM, countStyle: .memory)
    }

    public var formattedFreeRAM: String {
        ByteCountFormatter.string(fromByteCount: freeRAM, countStyle: .memory)
    }

    public var formattedSwapUsed: String {
        ByteCountFormatter.string(fromByteCount: swapUsed, countStyle: .memory)
    }

    public var formattedCompressedRAM: String {
        ByteCountFormatter.string(fromByteCount: compressedRAM, countStyle: .memory)
    }

    public var isSwapActive: Bool {
        swapUsed > (256 * 1024 * 1024) // > 256MB
    }
}

// MARK: - Process Category

public enum ProcessCategory: String, Sendable, Codable, CaseIterable {
    case llmRuntime = "AI & LLM Runtimes"
    case devTooling = "Developer Toolchains"
    case zombieWorker = "Idle Background Workers"
    case browserElectron = "Browsers & Apps"
    case system = "macOS System"

    public var iconName: String {
        switch self {
        case .llmRuntime: return "brain"
        case .devTooling: return "terminal"
        case .zombieWorker: return "hourglass"
        case .browserElectron: return "window"
        case .system: return "apple.logo"
        }
    }
}

// MARK: - Process Insight

public struct ProcessInsight: Identifiable, Sendable, Codable, Equatable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let name: String
    public let memoryBytes: Int64
    public let category: ProcessCategory
    public let cpuPercent: Double
    public let elapsedTimeString: String
    public let details: String

    public init(
        pid: Int32,
        name: String,
        memoryBytes: Int64,
        category: ProcessCategory,
        cpuPercent: Double,
        elapsedTimeString: String,
        details: String
    ) {
        self.pid = pid
        self.name = name
        self.memoryBytes = memoryBytes
        self.category = category
        self.cpuPercent = cpuPercent
        self.elapsedTimeString = elapsedTimeString
        self.details = details
    }

    public var formattedMemory: String {
        ByteCountFormatter.string(fromByteCount: memoryBytes, countStyle: .memory)
    }
}

// MARK: - Root Cause Insight

public struct RootCauseInsight: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let severity: MemoryPressureLevel
    public let title: String
    public let explanation: String
    public let impact: String
    public let targetProcessOrModel: String?

    public init(
        id: UUID = UUID(),
        severity: MemoryPressureLevel,
        title: String,
        explanation: String,
        impact: String,
        targetProcessOrModel: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.title = title
        self.explanation = explanation
        self.impact = impact
        self.targetProcessOrModel = targetProcessOrModel
    }
}

// MARK: - Recommendation Action Kind

public enum RecommendationActionKind: String, Sendable, Codable {
    case unloadLLM = "Unload LLM Model"
    case purgeRAM = "Purge Inactive File Buffers"
    case cleanCaches = "Clean Stale Caches"
    case reviewProcess = "Review Heavy Process"
}

// MARK: - Safe Recommendation

public struct PressureRecommendation: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let title: String
    public let description: String
    public let actionKind: RecommendationActionKind
    public let estimatedReclaimBytes: Int64
    public let commandOrAction: String?

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        actionKind: RecommendationActionKind,
        estimatedReclaimBytes: Int64,
        commandOrAction: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.actionKind = actionKind
        self.estimatedReclaimBytes = estimatedReclaimBytes
        self.commandOrAction = commandOrAction
    }

    public var formattedReclaim: String {
        ByteCountFormatter.string(fromByteCount: estimatedReclaimBytes, countStyle: .memory)
    }
}

// MARK: - Comprehensive Pressure Report

public struct PressureReport: Sendable, Codable, Equatable {
    public let timestamp: Date
    public let pressureLevel: MemoryPressureLevel
    public let metrics: MemoryMetrics
    public let summary: String
    public let rootCauses: [RootCauseInsight]
    public let topConsumers: [ProcessInsight]
    public let recommendations: [PressureRecommendation]

    public init(
        timestamp: Date = Date(),
        pressureLevel: MemoryPressureLevel,
        metrics: MemoryMetrics,
        summary: String,
        rootCauses: [RootCauseInsight],
        topConsumers: [ProcessInsight],
        recommendations: [PressureRecommendation]
    ) {
        self.timestamp = timestamp
        self.pressureLevel = pressureLevel
        self.metrics = metrics
        self.summary = summary
        self.rootCauses = rootCauses
        self.topConsumers = topConsumers
        self.recommendations = recommendations
    }
}
