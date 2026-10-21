// RubyAnalyzer.swift
// Core/Analyzers
//
// Classifies Ruby version manager sprawl: rbenv, rvm, gem/bundler caches.

import Foundation

public struct RubyAnalyzer: StorageAnalyzer {

    public let id = "com.reclaim.ruby"
    public let displayName = "Ruby"

    private static let markers: [String] = [
        "/.rbenv/versions", "/.rbenv/shims",
        "/.rvm/rubies", "/.rvm/gems", "/.rvm/archives", "/.rvm/log",
        "/.gem/ruby",
        "/gems/cache", "/.bundle/cache", "/vendor/bundle", "/.cache/bundle",
    ]

    public func canAnalyze(_ item: StorageItem) -> Bool {
        let lower = item.path.lowercased()
        return Self.markers.contains { lower.contains($0) }
    }

    public func analyze(item: StorageItem, context: AnalysisContext) async throws -> AnalysisResult {
        let lower = item.path.lowercased()

        var enriched = item
        enriched.category = .ruby
        enriched.analyzerID = id

        let note: String

        switch true {
        // ── Must be checked BEFORE rbenv version match ──
        // Actual rbenv gem cache path: ~/.rbenv/versions/X/lib/ruby/gems/X.Y.Z/cache/
        // Bundler cache: ~/.bundle/cache/  or  vendor/bundle/ruby/X.Y.Z/cache/
        case (lower.contains("/ruby/gems/") && lower.contains("/cache/"))
            || lower.contains("/.bundle/cache")
            || lower.contains("/.cache/bundle"):
            enriched.risk = .safe
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "Bundler / RubyGems download cache — re-fetched automatically"
            note = "gem/bundler cache"

        case lower.contains("/.rvm/archives"):
            enriched.risk = .safe
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "RVM Ruby source archives — re-downloaded by RVM when needed"
            note = "RVM archives"

        case lower.contains("/.rvm/log"):
            enriched.risk = .safe
            enriched.recoverability = .regeneratable
            enriched.whatIsThis = "RVM installation log files — safe to remove"
            note = "RVM logs"

        case lower.contains("/.rbenv/versions"):
            enriched.risk = .low
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "rbenv Ruby version — re-installable with `rbenv install <version>`"
            enriched.recoveryInstruction = "Run: rbenv install <version>"
            note = "rbenv Ruby version"

        case lower.contains("/.rvm/rubies"):
            enriched.risk = .low
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "RVM Ruby installation — re-installable with `rvm install <version>`"
            enriched.recoveryInstruction = "Run: rvm install <version>"
            note = "RVM Ruby"

        case lower.contains("/.rvm/gems"):
            enriched.risk = .low
            enriched.recoverability = .rebuildable
            enriched.whatIsThis = "RVM gemset — rebuildable with `bundle install`"
            enriched.recoveryInstruction = "Run: bundle install"
            note = "RVM gemset"

        case lower.contains("/vendor/bundle"):
            enriched.risk = .low
            enriched.recoverability = .rebuildable
            enriched.whatIsThis = "Vendored bundle — recreatable with `bundle install --path vendor/bundle`"
            note = "vendor/bundle"

        default:
            enriched.risk = .low
            enriched.recoverability = .redownloadable
            enriched.whatIsThis = "Ruby environment artifact"
            note = "Ruby artifact"
        }

        return AnalysisResult(
            item: enriched,
            evidence: [Evidence(kind: .note, description: note)],
            isCleanupCandidate: true
        )
    }
}
