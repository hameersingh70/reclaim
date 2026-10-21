// XcodeAnalyzer.swift
// Analyzers/Xcode
//
// Identifies DerivedData, Archives, DeviceSupport, and Simulators per PRD §9.

import Foundation

public struct XcodeAnalyzer: StorageAnalyzer {
    public let id = "com.reclaim.analyzers.xcode"
    public let displayName = "Xcode Analyzer"

    public init() {}

    public func canAnalyze(_ item: StorageItem) -> Bool {
        let lower = item.path.lowercased()
        return lower.contains("deriveddata")
            || lower.contains(".xcarchive")
            || lower.contains("devicesupport")
            || lower.contains("coresimulator")
            || lower.contains("xcode")
            || lower.contains("simruntime")
    }

    public func analyze(item: StorageItem, context: AnalysisContext) async throws -> AnalysisResult {
        var enriched = item
        enriched.category = .xcode
        enriched.analyzerID = id

        let lower = item.path.lowercased()
        var evidence: [Evidence] = []
        var isCandidate = false
        var rejectionReason: String? = nil

        if lower.contains("deriveddata") {
            enriched.risk = .safe
            enriched.recoverability = .rebuildable
            enriched.whatIsThis = "Xcode DerivedData (build artifacts)"
            enriched.whyItExists = "Stores intermediate build products, indexes, and compilation logs."
            enriched.removalConsequence = "Your next Xcode build may take longer because intermediate build artifacts will be recreated."
            enriched.recoveryInstruction = "Automatic during the next Xcode build."
            isCandidate = true
            evidence.append(Evidence(kind: .pathMatch, description: "Matched Xcode DerivedData directory"))
        } else if lower.contains(".xcarchive") || lower.contains("/archives") {
            enriched.risk = .medium
            enriched.recoverability = .applicationState
            enriched.whatIsThis = "Xcode build archive (.xcarchive)"
            enriched.whyItExists = "Packaged app release builds and dSYM debug symbol bundles."
            enriched.removalConsequence = "Removes archived releases and crash symbolication files."
            enriched.recoveryInstruction = "Cannot be recreated without re-archiving source code at the exact commit."
            isCandidate = false
            rejectionReason = "Archives require user review before deletion."
            evidence.append(Evidence(kind: .note, description: "Build archive bundle requiring review"))
        } else if lower.contains("devicesupport") {
            enriched.risk = .low
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "iOS/watchOS/tvOS Device Support Symbols"
            enriched.whyItExists = "Debug symbols extracted from physical iOS devices connected to your Mac."
            enriched.removalConsequence = "Physical device debugging will re-extract symbols when the device is plugged in."
            enriched.recoveryInstruction = "Symbols are re-extracted automatically when connecting the device."
            isCandidate = true
            evidence.append(Evidence(kind: .pathMatch, description: "Matched iOS DeviceSupport symbols"))
        } else if lower.contains("simruntime") || lower.contains("/runtimes") {
            enriched.risk = .low
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "iOS Simulator Runtime"
            enriched.whyItExists = "Disk images for additional simulator OS versions (e.g. iOS 16, watchOS 9)."
            enriched.removalConsequence = "Simulator OS runtime will no longer be available in Xcode."
            enriched.recoveryInstruction = "Can be downloaded again via Xcode > Settings > Platforms."
            isCandidate = true
            evidence.append(Evidence(kind: .pathMatch, description: "Matched Simulator Runtime package"))
        } else if lower.contains("/devices/") || lower.contains("/coresimulator") {
            enriched.risk = .medium
            enriched.recoverability = .applicationState
            enriched.whatIsThis = "Simulator device sandbox data"
            enriched.whyItExists = "App installs and sandboxed user data inside simulator instances."
            enriched.removalConsequence = "Resets installed test apps and test accounts on the simulator."
            enriched.recoveryInstruction = "Apps can be re-run from Xcode. Run 'xcrun simctl erase all' to reset."
            isCandidate = false
            rejectionReason = "Simulator sandbox contains test data; requires review."
        } else {
            enriched.risk = .medium
            enriched.recoverability = .unknown
            isCandidate = false
            rejectionReason = "Unclassified Xcode data."
        }

        return AnalysisResult(
            item: enriched,
            evidence: evidence,
            isCleanupCandidate: isCandidate,
            rejectionReason: rejectionReason
        )
    }
}
