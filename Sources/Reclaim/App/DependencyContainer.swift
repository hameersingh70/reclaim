// DependencyContainer.swift
// App/
//
// The composition root for Reclaim.
// All dependencies are constructed here and injected — no module may
// instantiate its own dependencies (PRD §35.8: use dependency injection).
//
// This file is the only place that knows about concrete implementations.

import Foundation

/// Composition root that constructs and wires all application services.
///
/// The GUI app, CLI, and future menu-bar companion each create one container
/// with the same configuration. The core engine has no knowledge of which
/// surface is hosting it (PRD §55).
public final class DependencyContainer: Sendable {

    // MARK: - Core services

    /// The registry of all ecosystem analyzers.
    public let analyzerRegistry: AnalyzerRegistry

    /// The current application configuration.
    public let configuration: ReclaimConfiguration

    // MARK: - Init

    /// Creates a container pre-populated with the default set of analyzers
    /// for the MVP (Phase 6–8 analyzers are registered here as they are built).
    public init(configuration: ReclaimConfiguration = .default, analyzerRegistry: AnalyzerRegistry = AnalyzerRegistry()) {
        self.configuration = configuration
        self.analyzerRegistry = analyzerRegistry
    }

    /// Convenience factory that pre-registers all analyzers.
    public static func createWithDefaultAnalyzers(configuration: ReclaimConfiguration = .default) async -> DependencyContainer {
        let registry = AnalyzerRegistry()
        await registry.register([
            // Developer Ecosystems
            GradleAnalyzer(),
            NodeAnalyzer(),
            HomebrewAnalyzer(),
            DockerAnalyzer(),
            XcodeAnalyzer(),
            RubyAnalyzer(),
            JVMAnalyzer(),
            // AI / ML / Data Science
            LLMAnalyzer(),
            MLFrameworksAnalyzer(),
            PythonEnvAnalyzer(),
            // System Cleanup
            BackupAnalyzer(),
        ])
        return DependencyContainer(configuration: configuration, analyzerRegistry: registry)
    }
}

// MARK: - ReclaimConfiguration

/// Application-wide configuration.
/// All thresholds are externalised here rather than scattered through modules.
public struct ReclaimConfiguration: Sendable {

    /// Age in days after which an unaccessed item may be considered stale.
    public var staleThresholdDays: Int

    /// Whether cleanup operations move items to Trash (recommended)
    /// or permanently delete them.
    public var useTrashForCleanup: Bool

    /// Paths that the scanner should never traverse.
    /// In addition to the hardcoded `SafetyEngine.protectedPaths`.
    public var userExcludedPaths: Set<String>

    public static let `default` = ReclaimConfiguration(
        staleThresholdDays: 90,
        useTrashForCleanup: true,
        userExcludedPaths: []
    )

    public init(
        staleThresholdDays: Int,
        useTrashForCleanup: Bool,
        userExcludedPaths: Set<String>
    ) {
        self.staleThresholdDays = staleThresholdDays
        self.useTrashForCleanup = useTrashForCleanup
        self.userExcludedPaths = userExcludedPaths
    }
}
