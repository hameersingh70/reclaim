// SafetyEngine.swift
// Core/Engine
//
// Centralized safety enforcement according to PRD §4.1, §12, and §13.
// Protected paths and credentials must override any analyzer recommendations.

import Foundation

public struct SafetyEngine: Sendable {

    /// System paths that must NEVER be touched under any circumstances.
    public static let systemProtectedPrefixes: [String] = [
        "/System",
        "/bin",
        "/sbin",
        "/usr/bin",
        "/usr/sbin",
        "/usr/lib",
        "/Library/Keychains",
        "/private/var/db"
    ]

    /// Patterns matching credentials, keys, and critical configuration files.
    public static let protectedPatterns: [String] = [
        "/.ssh",
        "/dot-ssh",
        "/.gnupg",
        "/dot-gnupg",
        "/.aws",
        "/dot-aws",
        "/.kube",
        "/dot-kube",
        "/.docker/config.json",
        "/settings.xml",
        "keychain",
        "id_rsa",
        "id_ed25519",
        "/.env",
        "/dot-m2"
    ]

    public init() {}

    /// Checks if a given path is strictly protected from any cleanup.
    public func isProtected(path: String) -> Bool {
        for prefix in Self.systemProtectedPrefixes {
            if path == prefix || path.hasPrefix(prefix + "/") {
                return true
            }
        }
        let lower = path.lowercased()
        for pattern in Self.protectedPatterns {
            if lower.contains(pattern) {
                return true
            }
        }
        return false
    }

    /// Evaluates an item and overrides its risk level if it matches protected rules
    /// or user document guardrails.
    public func enforceSafety(on item: StorageItem) -> StorageItem {
        var assessed = item

        if isProtected(path: item.path) {
            assessed.risk = .protected
            return assessed
        }

        let lower = item.path.lowercased()
        if (lower.contains("/documents/") || lower.contains("/desktop/")) &&
            !item.path.contains("node_modules") &&
            !item.path.contains(".venv") &&
            !item.path.contains("/venv") {
            // User-created documents must never become automatic cleanup candidates
            if assessed.risk == .safe || assessed.risk == .low {
                assessed.risk = .high
            }
        }

        return assessed
    }

    /// Convenience alias
    public func assess(item: StorageItem) -> StorageItem {
        return enforceSafety(on: item)
    }

    /// Applies safety enforcement to an AnalysisResult.
    /// If an item is protected or high-risk, cleanup candidate is cleared.
    public func assess(result: AnalysisResult) -> AnalysisResult {
        let assessedItem = enforceSafety(on: result.item)

        if assessedItem.risk == .protected {
            return AnalysisResult(
                item: assessedItem,
                evidence: result.evidence + [Evidence(kind: .note, description: "Protected by SafetyEngine")],
                isCleanupCandidate: false,
                rejectionReason: "Protected path cannot be deleted."
            )
        } else if assessedItem.risk == .high || assessedItem.risk == .unknown {
            return AnalysisResult(
                item: assessedItem,
                evidence: result.evidence,
                isCleanupCandidate: false,
                rejectionReason: "High or unknown risk requires manual review."
            )
        }

        return AnalysisResult(
            item: assessedItem,
            evidence: result.evidence,
            isCleanupCandidate: result.isCleanupCandidate,
            rejectionReason: result.rejectionReason
        )
    }
}
