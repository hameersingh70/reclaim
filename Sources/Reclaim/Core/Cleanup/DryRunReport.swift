// DryRunReport.swift
// Core/Cleanup
//
// Structured dry-run output detailing exact actions and recovery consequences
// without modifying the filesystem (PRD §19).

import Foundation

public struct DryRunItem: Sendable {
    public let path: String
    public let logicalSize: Int64
    public let allocatedSize: Int64
    public let reason: String
    public let analyzerID: String?
    public let risk: StorageRiskLevel
    public let recoveryMechanism: String

    public init(item: StorageItem) {
        self.path = item.path
        self.logicalSize = item.logicalSize
        self.allocatedSize = item.allocatedSize
        self.reason = item.whatIsThis ?? item.category.displayName
        self.analyzerID = item.analyzerID
        self.risk = item.risk
        self.recoveryMechanism = item.recoveryInstruction ?? item.recoverability.displayLabel
    }
}

public struct DryRunReport: Sendable {
    public let items: [DryRunItem]
    public let totalLogicalBytes: Int64
    public let totalAllocatedBytes: Int64
    public let totalEstimatedReclaimableBytes: Int64

    public init(plan: ReclaimPlan) {
        self.items = plan.candidates.map { DryRunItem(item: $0.item) }
        self.totalLogicalBytes = plan.candidates.reduce(0) { $0 + $1.item.logicalSize }
        self.totalAllocatedBytes = plan.candidates.reduce(0) { $0 + $1.item.allocatedSize }
        self.totalEstimatedReclaimableBytes = plan.totalReclaimableBytes
    }

    public var formattedReclaimable: String {
        ByteCountFormatter.string(fromByteCount: totalEstimatedReclaimableBytes, countStyle: .file)
    }
}
