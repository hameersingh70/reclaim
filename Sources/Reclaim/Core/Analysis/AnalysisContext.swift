// AnalysisContext.swift
// Core/Analysis
//
// Passed to every StorageAnalyzer.analyze() call.
// Provides shared services and configuration without coupling
// analyzers to global state.

import Foundation

/// Contextual services and configuration provided to every analyzer invocation.
///
/// Analyzers must not access global singletons directly.
/// All required dependencies are injected through this context.
public struct AnalysisContext: Sendable {

    /// The filesystem URL being analysed (may be a file or directory root).
    public let rootURL: URL

    /// User-level home directory. Used by analyzers to resolve `~/` paths.
    public let homeURL: URL

    /// The current date, injected so tests can control time-based logic
    /// (e.g. "stale if not accessed for 90 days").
    public let now: Date

    /// Configurable age threshold (in days) after which an item may be
    /// considered stale. Defaults to 90 days. Analyzers use this rather
    /// than hard-coding a value.
    public let staleThresholdDays: Int

    public init(
        rootURL: URL,
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        now: Date = Date(),
        staleThresholdDays: Int = 90
    ) {
        self.rootURL = rootURL
        self.homeURL = homeURL
        self.now = now
        self.staleThresholdDays = staleThresholdDays
    }

    /// Returns the cutoff date before which an item is considered stale.
    public var staleDate: Date {
        Calendar.current.date(
            byAdding: .day,
            value: -staleThresholdDays,
            to: now
        ) ?? now
    }

    /// Resolves a `~/` prefixed path to an absolute URL using the injected
    /// home directory rather than the process home, making tests portable.
    public func resolving(tildeRelativePath: String) -> URL {
        let expanded = tildeRelativePath.hasPrefix("~/")
            ? homeURL.appendingPathComponent(String(tildeRelativePath.dropFirst(2)))
            : URL(fileURLWithPath: tildeRelativePath)
        return expanded
    }
}
