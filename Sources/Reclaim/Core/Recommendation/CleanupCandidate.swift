// CleanupCandidate.swift
// Core/Recommendation
//
// Represents an eligible item in the Reclaim Planner candidate pool with
// an assigned optimization priority based on risk and recoverability (PRD §17).

import Foundation

public struct CleanupCandidate: Identifiable, Sendable {
    public let id: UUID
    public let item: StorageItem
    public let priority: Int
    public let reclaimableBytes: Int64

    public init(item: StorageItem, customPriority: Int? = nil) {
        self.id = UUID()
        self.item = item
        self.reclaimableBytes = item.estimatedReclaimableSize

        if let p = customPriority {
            self.priority = p
        } else {
            // Priority order per PRD §17:
            // 1. safe regeneratable caches
            // 2. stale rebuildable data
            // 3. redownloadable SDK/runtime data
            // 4. explicitly reviewed items
            switch (item.risk, item.recoverability) {
            case (.safe, .regeneratable):
                self.priority = 1
            case (.safe, _):
                self.priority = 1
            case (.low, .rebuildable):
                self.priority = 2
            case (.low, .redownloadable):
                self.priority = 3
            case (.low, _):
                self.priority = 3
            case (.medium, _):
                self.priority = 4
            default:
                self.priority = 99
            }
        }
    }
}
