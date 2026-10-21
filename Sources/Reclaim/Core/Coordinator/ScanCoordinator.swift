// ScanCoordinator.swift
// Core/Coordinator
//
// Wires the FileScanner, GenericCategorizer, AnalyzerRegistry, and SafetyEngine
// into an asynchronous, streaming pipeline per PRD §6 and §10.

import Foundation

public final class ScanCoordinator: Sendable {
    public let categorizer: GenericCategorizer
    public let analyzerRegistry: AnalyzerRegistry
    public let safetyEngine: SafetyEngine

    public init(
        categorizer: GenericCategorizer = GenericCategorizer(),
        analyzerRegistry: AnalyzerRegistry = AnalyzerRegistry(),
        safetyEngine: SafetyEngine = SafetyEngine()
    ) {
        self.categorizer = categorizer
        self.analyzerRegistry = analyzerRegistry
        self.safetyEngine = safetyEngine
    }

    /// Scans a directory and streams fully analysed and safety-checked AnalysisResult items.
    public func scanAndAnalyze(rootURL: URL, context: AnalysisContext, maxDepth: Int? = nil) -> AsyncStream<AnalysisResult> {
        let scanner = FileScanner(rootURL: rootURL, maxDepth: maxDepth)

        return AsyncStream { continuation in
            let task = Task {
                for await rawItem in scanner.scan() {
                    if Task.isCancelled { break }

                    // 1. Pre-categorize with generic rules
                    var categorized = rawItem
                    categorized.category = categorizer.categorize(rawItem)

                    // 2. Domain analyzer enrichment
                    let analysisResult = await analyzerRegistry.analyze(item: categorized, context: context)

                    // 3. Centralized safety enforcement
                    let safeResult = safetyEngine.assess(result: analysisResult)

                    continuation.yield(safeResult)
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
