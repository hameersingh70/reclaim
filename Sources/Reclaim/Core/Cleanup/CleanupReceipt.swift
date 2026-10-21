// CleanupReceipt.swift
// Core/Cleanup
//
// Structured record of completed cleanup actions, space recovered,
// and recovery instructions per PRD §21.

import Foundation

public struct CleanupActionSummary: Codable, Sendable {
    public let path: String
    public let description: String
    public let reclaimedBytes: Int64
    public let success: Bool
    public let recoveryInstruction: String?

    public init(path: String, description: String, reclaimedBytes: Int64, success: Bool, recoveryInstruction: String? = nil) {
        self.path = path
        self.description = description
        self.reclaimedBytes = reclaimedBytes
        self.success = success
        self.recoveryInstruction = recoveryInstruction
    }
}

public struct CleanupReceipt: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let beforeAvailableBytes: Int64
    public let afterAvailableBytes: Int64
    public let actualRecoveredBytes: Int64
    public let actions: [CleanupActionSummary]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        beforeAvailableBytes: Int64,
        afterAvailableBytes: Int64,
        actions: [CleanupActionSummary]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.beforeAvailableBytes = beforeAvailableBytes
        self.afterAvailableBytes = afterAvailableBytes
        self.actualRecoveredBytes = max(0, afterAvailableBytes - beforeAvailableBytes)
        self.actions = actions
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        beforeAvailableBytes: Int64,
        afterAvailableBytes: Int64,
        actualRecoveredBytes: Int64,
        actions: [CleanupActionSummary]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.beforeAvailableBytes = beforeAvailableBytes
        self.afterAvailableBytes = afterAvailableBytes
        self.actualRecoveredBytes = actualRecoveredBytes
        self.actions = actions
    }

    public var formattedRecovered: String {
        ByteCountFormatter.string(fromByteCount: actualRecoveredBytes, countStyle: .file)
    }
}
