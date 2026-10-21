// StorageItem.swift
// Core/Storage
//
// The central domain model for every detected filesystem item.
// PRD §7 specifies the required fields and the distinction between
// logical size, allocated size, and estimated reclaimable size.

import Foundation

/// A single detected storage item on the filesystem.
///
/// Every item must answer the ten core product questions defined in PRD §3:
/// what it is, who created it, why it exists, how much space it uses,
/// whether it is in use, whether it is safe to remove, what happens if
/// removed, whether it can be recreated, how to recreate it, and what
/// confidence the system has.
public struct StorageItem: Identifiable, Codable, Sendable, Hashable {

    // MARK: - Identity

    public let id: UUID

    /// Absolute filesystem path of the item (file or directory root).
    public let path: String

    // MARK: - Size (PRD §7: these three values must not be assumed equal)

    /// Total logical size of all contained files in bytes.
    /// This is the sum of file data sizes, ignoring filesystem block rounding.
    public let logicalSize: Int64

    /// Actual physical bytes allocated on disk (respects block size).
    /// This is the value that changes when the item is deleted.
    public let allocatedSize: Int64

    /// Estimated bytes that would be recovered by the recommended cleanup
    /// operation. May be less than `allocatedSize` when partial cleanup
    /// is planned (e.g. only stale Gradle cache versions, not all of `.gradle`).
    public let estimatedReclaimableSize: Int64

    // MARK: - Timestamps

    public let createdAt: Date?
    public let modifiedAt: Date?

    /// Last time the item was accessed, if the filesystem records it.
    public let accessedAt: Date?

    // MARK: - Classification

    public var category: StorageCategory

    /// The identifier of the `StorageAnalyzer` that classified this item.
    /// `nil` when the item has not yet been analysed (generic scanner pass).
    public var analyzerID: String?

    public var risk: StorageRiskLevel
    public var recoverability: RecoverabilityType

    // MARK: - Explanation fields (PRD §3 core questions)

    /// Human-readable answer to "What is this?"
    public var whatIsThis: String?

    /// Human-readable answer to "Why does it exist?"
    public var whyItExists: String?

    /// Human-readable answer to "What happens if it is removed?"
    public var removalConsequence: String?

    /// Human-readable answer to "How is it recreated / restored?"
    public var recoveryInstruction: String?

    /// Optional natural-language explanation generated post-MVP.
    /// PRD §4.2: LLMs may explain but must never decide.
    public var explanation: String?

    // MARK: - Filesystem metadata

    /// True when the path points to a symbolic link.
    public var isSymlink: Bool

    /// True when multiple directory entries share the same inode (hard link).
    public var isHardLink: Bool

    /// The (device, inode) pair used for hard-link deduplication.
    /// Scanner tracks seen inodes to avoid double-counting allocated size.
    public var inodeKey: InodeKey?

    // MARK: - Init

    public init(
        id: UUID = UUID(),
        path: String,
        logicalSize: Int64,
        allocatedSize: Int64,
        estimatedReclaimableSize: Int64? = nil,
        createdAt: Date? = nil,
        modifiedAt: Date? = nil,
        accessedAt: Date? = nil,
        category: StorageCategory = .generic,
        analyzerID: String? = nil,
        risk: StorageRiskLevel = .unknown,
        recoverability: RecoverabilityType = .unknown,
        whatIsThis: String? = nil,
        whyItExists: String? = nil,
        removalConsequence: String? = nil,
        recoveryInstruction: String? = nil,
        explanation: String? = nil,
        isSymlink: Bool = false,
        isHardLink: Bool = false,
        inodeKey: InodeKey? = nil
    ) {
        self.id = id
        self.path = path
        self.logicalSize = logicalSize
        self.allocatedSize = allocatedSize
        self.estimatedReclaimableSize = estimatedReclaimableSize ?? allocatedSize
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.accessedAt = accessedAt
        self.category = category
        self.analyzerID = analyzerID
        self.risk = risk
        self.recoverability = recoverability
        self.whatIsThis = whatIsThis
        self.whyItExists = whyItExists
        self.removalConsequence = removalConsequence
        self.recoveryInstruction = recoveryInstruction
        self.explanation = explanation
        self.isSymlink = isSymlink
        self.isHardLink = isHardLink
        self.inodeKey = inodeKey
    }
}

// MARK: - InodeKey

/// A (device, inode) pair that uniquely identifies a file across hard links.
/// The scanner tracks seen InodeKeys to avoid double-counting physical storage.
public struct InodeKey: Hashable, Codable, Sendable {
    public let device: UInt64
    public let inode: UInt64

    public init(device: UInt64, inode: UInt64) {
        self.device = device
        self.inode = inode
    }
}

// MARK: - Convenience

extension StorageItem {

    /// Returns the display-friendly formatted size string for the allocated size.
    public var formattedAllocatedSize: String {
        ByteCountFormatter.string(
            fromByteCount: allocatedSize,
            countStyle: .file
        )
    }

    /// Returns the display-friendly formatted size string for reclaimable bytes.
    public var formattedReclaimableSize: String {
        ByteCountFormatter.string(
            fromByteCount: estimatedReclaimableSize,
            countStyle: .file
        )
    }

    /// Whether this item has been fully analysed by a domain analyzer.
    public var isAnalysed: Bool {
        analyzerID != nil
    }

    /// Whether this item may be included in a reclaim plan without
    /// explicit user override.
    public var isEligibleForPlan: Bool {
        risk.isEligibleForAutomaticPlan
    }
}
