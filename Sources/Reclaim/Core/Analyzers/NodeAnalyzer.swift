// NodeAnalyzer.swift
// Analyzers/Node
//
// Identifies npm, Yarn, pnpm, Bun caches, framework build caches,
// and project node_modules directories (with lockfile detection) per PRD §9.

import Foundation

public struct NodeAnalyzer: StorageAnalyzer {
    public let id = "com.reclaim.analyzers.node"
    public let displayName = "Node.js Analyzer"

    public init() {}

    public func canAnalyze(_ item: StorageItem) -> Bool {
        let lower = item.path.lowercased()
        return lower.contains("node_modules")
            || lower.contains("/.npm")
            || lower.contains("/.yarn")
            || lower.contains("/pnpm/store")
            || lower.contains("/.pnpm-store")
            || lower.contains("/.bun")
            || lower.contains("/.next")
            || lower.contains("/.nuxt")
            || lower.contains("/ms-playwright")
            || lower.contains("/puppeteer")
    }

    public func analyze(item: StorageItem, context: AnalysisContext) async throws -> AnalysisResult {
        var enriched = item
        enriched.category = .node
        enriched.analyzerID = id

        let lower = item.path.lowercased()
        var evidence: [Evidence] = []
        var isCandidate = false
        var rejectionReason: String? = nil

        if lower.contains("node_modules") {
            // Check for lockfiles in parent directory
            let parentURL = URL(fileURLWithPath: item.path).deletingLastPathComponent()
            let lockfiles = ["package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb"]
            var foundLockfile: String? = nil

            for lock in lockfiles {
                let lockURL = parentURL.appendingPathComponent(lock)
                if FileManager.default.fileExists(atPath: lockURL.path) {
                    foundLockfile = lock
                    break
                }
            }

            enriched.whatIsThis = "Project dependencies (node_modules)"
            enriched.whyItExists = "Installed third-party JavaScript/TypeScript packages for a project."
            enriched.removalConsequence = "Project cannot be run or built until dependencies are reinstalled."
            
            if let lock = foundLockfile {
                enriched.risk = .low
                enriched.recoverability = .rebuildable
                enriched.recoveryInstruction = "Reconstructible via npm install, yarn, pnpm install, or bun install."
                isCandidate = true
                evidence.append(Evidence(
                    kind: .lockfilePresent,
                    description: "Detected lockfile: \(lock)",
                    referencePath: parentURL.appendingPathComponent(lock).path
                ))
            } else {
                enriched.risk = .medium
                enriched.recoverability = .unknown
                enriched.recoveryInstruction = "Run package manager install, but exact versions may change without a lockfile."
                isCandidate = false
                rejectionReason = "No lockfile detected; dependency reproduction may be non-deterministic."
                evidence.append(Evidence(
                    kind: .note,
                    description: "No package-lock.json, yarn.lock, pnpm-lock.yaml, or bun.lockb found in parent"
                ))
            }
        } else if lower.contains("/ms-playwright") || lower.contains("/puppeteer") {
            // Browser automation binaries (Playwright / Puppeteer)
            enriched.risk = .safe
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "Test browser binaries (Playwright/Puppeteer)"
            enriched.whyItExists = "Downloaded browser binaries (Chromium, Firefox, WebKit) for end-to-end testing."
            enriched.removalConsequence = "Re-downloaded automatically via `npx playwright install` or `npx puppeteer browsers install`."
            enriched.recoveryInstruction = "Run `npx playwright install` when running browser tests next time."
            isCandidate = true
            evidence.append(Evidence(kind: .pathMatch, description: "Matched test browser binary cache"))
        } else if lower.contains("/.npm") || lower.contains("/.yarn") || lower.contains("pnpm") || lower.contains("/.bun") {
            // Global package manager download caches
            enriched.risk = .safe
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "Package manager cache"
            enriched.whyItExists = "Cached tarballs and metadata to speed up future package installations."
            enriched.removalConsequence = "Next install will fetch tarballs from registry."
            enriched.recoveryInstruction = "Automatic on next install."
            isCandidate = true
            evidence.append(Evidence(kind: .pathMatch, description: "Matched global package cache"))
        } else if lower.contains("/.next") || lower.contains("/.nuxt") {
            // Framework build caches
            enriched.risk = .safe
            enriched.recoverability = .rebuildable
            enriched.whatIsThis = "Framework build cache"
            enriched.whyItExists = "Incremental compilation outputs."
            enriched.removalConsequence = "Next build will recompile all components."
            enriched.recoveryInstruction = "Automatic on next dev/build."
            isCandidate = true
            evidence.append(Evidence(kind: .pathMatch, description: "Matched framework build cache"))
        } else {
            enriched.risk = .medium
            enriched.recoverability = .unknown
            isCandidate = false
            rejectionReason = "Unclassified Node storage item."
        }

        return AnalysisResult(
            item: enriched,
            evidence: evidence,
            isCleanupCandidate: isCandidate,
            rejectionReason: rejectionReason
        )
    }
}
