// DockerAnalyzer.swift
// Analyzers/Docker
//
// Identifies Docker Desktop disk image, build cache, and persistent volumes per PRD §9.
// Persistent volumes must NEVER be automatically classified as safe.

import Foundation

public struct DockerAnalyzer: StorageAnalyzer {
    public let id = "com.reclaim.analyzers.docker"
    public let displayName = "Docker Analyzer"

    public init() {}

    public func canAnalyze(_ item: StorageItem) -> Bool {
        let lower = item.path.lowercased()
        return lower.contains("docker") || lower.contains("buildkit")
    }

    public func analyze(item: StorageItem, context: AnalysisContext) async throws -> AnalysisResult {
        var enriched = item
        enriched.category = .docker
        enriched.analyzerID = id

        let lower = item.path.lowercased()
        var evidence: [Evidence] = []
        var isCandidate = false
        var rejectionReason: String? = nil

        if lower.contains("volumes") {
            // Persistent volumes must NEVER be automatically classified as safe
            enriched.risk = .high
            enriched.recoverability = .userData
            enriched.whatIsThis = "Docker persistent volume"
            enriched.whyItExists = "Stores stateful container data (databases, user uploads)."
            enriched.removalConsequence = "Permanent data loss of container volumes!"
            enriched.recoveryInstruction = "Cannot be recreated automatically. Requires database backup."
            isCandidate = false
            rejectionReason = "Docker persistent volumes require explicit manual review."
            evidence.append(Evidence(kind: .note, description: "Identified persistent volume; protected from auto-cleanup"))
        } else if lower.contains("buildkit") || lower.contains("build-cache") || lower.contains("builder") {
            // Docker build cache
            enriched.risk = .safe
            enriched.recoverability = .regeneratable
            enriched.whatIsThis = "Docker build cache"
            enriched.whyItExists = "Intermediate layer cache to speed up 'docker build'."
            enriched.removalConsequence = "Next docker build will re-download base images and re-run build steps."
            enriched.recoveryInstruction = "Rebuilt on next 'docker build'. Recommended: 'docker builder prune'."
            isCandidate = true
            evidence.append(Evidence(kind: .pathMatch, description: "Matched Docker build cache"))
        } else if lower.hasSuffix(".raw") || lower.contains("docker.raw") {
            // Main VM disk image
            enriched.risk = .high
            enriched.recoverability = .applicationState
            enriched.whatIsThis = "Docker Desktop virtual disk image"
            enriched.whyItExists = "The root filesystem for the Linux VM running Docker containers."
            enriched.removalConsequence = "Deletes all local containers, images, and volumes."
            enriched.recoveryInstruction = "Docker Desktop recreates an empty VM image, but all images must be pulled again. Use 'docker system prune' instead."
            isCandidate = false
            rejectionReason = "Direct deletion of Docker.raw corrupts Docker Desktop. Use 'docker system prune'."
            evidence.append(Evidence(kind: .note, description: "Docker Desktop VM disk image"))
        } else {
            enriched.risk = .medium
            enriched.recoverability = .unknown
            isCandidate = false
            rejectionReason = "Unclassified Docker internal files."
        }

        return AnalysisResult(
            item: enriched,
            evidence: evidence,
            isCleanupCandidate: isCandidate,
            rejectionReason: rejectionReason
        )
    }
}
