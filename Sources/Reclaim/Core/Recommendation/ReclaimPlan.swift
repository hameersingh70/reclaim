// ReclaimPlan.swift
// Core/Recommendation
//
// Represents a generated cleanup plan for a target space goal (PRD §17).

import Foundation

public struct ReclaimPlan: Sendable {
    public let targetBytes: Int64
    public let candidates: [CleanupCandidate]
    public let totalReclaimableBytes: Int64
    public let overallRisk: StorageRiskLevel

    public var isTargetMet: Bool {
        return totalReclaimableBytes >= targetBytes
    }

    public var formattedTarget: String {
        ByteCountFormatter.string(fromByteCount: targetBytes, countStyle: .file)
    }

    public var formattedReclaimable: String {
        ByteCountFormatter.string(fromByteCount: totalReclaimableBytes, countStyle: .file)
    }

    public init(targetBytes: Int64, candidates: [CleanupCandidate]) {
        self.targetBytes = targetBytes
        self.candidates = candidates
        self.totalReclaimableBytes = candidates.reduce(0) { $0 + $1.reclaimableBytes }

        if candidates.contains(where: { $0.item.risk == .medium }) {
            self.overallRisk = .medium
        } else if candidates.contains(where: { $0.item.risk == .low }) {
            self.overallRisk = .low
        } else if !candidates.isEmpty {
            self.overallRisk = .safe
        } else {
            self.overallRisk = .safe
        }
    }
}
