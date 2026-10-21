// BackupAnalyzer.swift
// Core/Analyzers
//
// Classifies backup and archive storage:
// iPhone/iPad MobileSync backups, device support symbols, .dmg/.iso disk images,
// .xip Xcode archives, .ipa files, .pkg installers.

import Foundation

public struct BackupAnalyzer: StorageAnalyzer {

    public let id = "com.reclaim.backups"
    public let displayName = "Backups & Archives"

    private static let pathMarkers: [String] = [
        "/library/application support/mobilesync/backup",
        "/mobilesync/backup",
    ]

    private static let diskImageExtensions: Set<String> = [
        "dmg", "iso", "img", "xip", "ipa", "pkg", "mpkg"
    ]

    public func canAnalyze(_ item: StorageItem) -> Bool {
        let lower = item.path.lowercased()
        if Self.pathMarkers.contains(where: { lower.contains($0) }) { return true }
        let ext = URL(fileURLWithPath: item.path).pathExtension.lowercased()
        return Self.diskImageExtensions.contains(ext) && item.allocatedSize > 100_000_000
    }

    public func analyze(item: StorageItem, context: AnalysisContext) async throws -> AnalysisResult {
        let lower = item.path.lowercased()
        let ext = URL(fileURLWithPath: item.path).pathExtension.lowercased()

        var enriched = item
        enriched.category = .backups
        enriched.analyzerID = id

        let isCandidate: Bool
        let note: String

        switch true {
        case lower.contains("/mobilesync/backup"):
            enriched.risk = .high
            enriched.recoverability = .userData
            enriched.whatIsThis = "iPhone/iPad backup — irreplaceable user data. Manage via Finder or iCloud."
            enriched.removalConsequence = "This backup cannot be recovered once deleted."
            isCandidate = false
            note = "iPhone/iPad backup — user data"

        case ext == "xip":
            enriched.risk = .low
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "Xcode/Apple software archive (.xip) — re-downloadable from Apple Developer portal"
            enriched.recoveryInstruction = "Re-download from developer.apple.com"
            isCandidate = true
            note = "Xcode .xip archive"

        case ext == "dmg" || ext == "iso" || ext == "img":
            enriched.risk = .medium
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "Disk image (\(ext.uppercased())) — old installer or backup, verify before deleting"
            isCandidate = true
            note = "Disk image (\(ext))"

        case ext == "ipa":
            enriched.risk = .medium
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "iOS app archive (.ipa) — re-buildable or re-downloadable"
            isCandidate = true
            note = "iOS .ipa archive"

        case ext == "pkg" || ext == "mpkg":
            enriched.risk = .low
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "macOS installer package — safe to remove after installation is complete"
            isCandidate = true
            note = "macOS installer .pkg"

        default:
            enriched.risk = .medium
            enriched.recoverability = .userData
            enriched.whatIsThis = "Backup or archive file — review before deleting"
            isCandidate = false
            note = "Archive — manual review needed"
        }

        return AnalysisResult(
            item: enriched,
            evidence: [Evidence(kind: .note, description: note)],
            isCleanupCandidate: isCandidate,
            rejectionReason: isCandidate ? nil : "User backup — not auto-cleaned"
        )
    }
}
