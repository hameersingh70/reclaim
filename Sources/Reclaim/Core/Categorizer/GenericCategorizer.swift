// GenericCategorizer.swift
// Core/Categorizer
//
// Assigns a StorageCategory to a StorageItem based on its filesystem path.
// Covers developer, AI/ML, Python, Ruby, JVM, backup, and media personas.

import Foundation

public struct GenericCategorizer: Sendable {

    public init() {}

    /// Returns the best-guess `StorageCategory` for the given path.
    /// Domain analyzers may refine this further.
    public func categorize(path: String) -> StorageCategory {
        let lower = path.lowercased()

        // ── AI / ML / LLM ─────────────────────────────────────────────────────
        if lower.contains("/.ollama/") || lower.contains("/lm studio/")
            || lower.contains("/lmstudio/") || lower.contains("/jan/models")
            || lower.contains("/gpt4all") || lower.contains("/llamafile")
            || lower.contains("/.cache/lm_studio") {
            return .llm
        }
        if lower.contains("/.cache/huggingface") {
            // Hub = model blobs → llm; datasets → mlFrameworks
            return lower.contains("/datasets") ? .mlFrameworks : .llm
        }
        if lower.contains("/.cache/torch") || lower.contains("/.triton/")
            || lower.contains("/mlruns/") || lower.contains("/wandb/")
            || lower.contains("/.dvc/") || lower.contains("/.ipynb_checkpoints")
            || lower.contains("/.cache/tfhub") || lower.contains("/.keras/")
            || lower.contains("/tensorboard/") || lower.contains("/lightning_logs/")
            || lower.contains("/ray_results/") || lower.contains("/.cache/datasets") {
            return .mlFrameworks
        }

        // ── Python Environments ───────────────────────────────────────────────
        if lower.contains("/.pyenv/") || lower.contains("/miniconda")
            || lower.contains("/anaconda") || lower.contains("/.conda/")
            || lower.contains("/miniforge") || lower.contains("/mambaforge")
            || lower.contains("/.cache/pip") || lower.contains("/library/caches/pip")
            || lower.contains("/.cache/uv") || lower.contains("/.cache/pypoetry")
            || lower.contains("/pypoetry")
            || lower.contains("/__pycache__")
            || lower.contains("/.pytest_cache") || lower.contains("/.tox/") {
            return .pythonEnv
        }

        // ── Ruby ──────────────────────────────────────────────────────────────
        if lower.contains("/.rbenv/") || lower.contains("/.rvm/")
            || lower.contains("/.gem/ruby") || lower.contains("/vendor/bundle") {
            return .ruby
        }

        // ── JVM / Java ────────────────────────────────────────────────────────
        if lower.contains("/javavirtualmachines") || lower.contains("/.konan")
            || lower.contains("/.ivy2/") || lower.contains("/.sbt")
            || lower.contains("/.cache/coursier") || lower.contains("/.coursier") {
            return .jvm
        }

        // ── Rust / Cargo ──────────────────────────────────────────────────────
        if lower.contains("/.cargo/") || lower.contains("/cargo/registry") || lower.contains("/cargo/git") {
            return .rust
        }

        // ── Existing Developer Ecosystems ──────────────────────────────────────
        if containsComponent(lower, ".gradle") || lower.contains("gradle") { return .gradle }
        if containsComponent(lower, "node_modules")
            || lower.contains("/.npm") || lower.contains("/.yarn")
            || lower.contains("/.pnpm-store") || lower.contains("/pnpm/store")
            || lower.contains("/bun/") || lower.contains("/.bun")
            || lower.contains("/ms-playwright") || lower.contains("/puppeteer") { return .node }
        if lower.contains("/docker") || lower.contains("/.docker") { return .docker }
        if lower.contains("/xcode") || lower.contains("/deriveddata")
            || lower.contains("/coresimulator") || lower.contains(".xcarchive") { return .xcode }
        if lower.contains("/.m2") || lower.contains("/maven") { return .maven }
        if lower.contains("/android") || lower.contains("/.android") { return .android }
        if lower.contains("/homebrew") || lower.contains("/.homebrew")
            || lower.contains("/cellar/") || lower.contains("/linuxbrew") { return .homebrew }
        if lower.contains("/library/caches/jetbrains") || lower.contains("/.cache/jetbrains") { return .generic }

        // ── Backups & Archives ─────────────────────────────────────────────────
        if lower.contains("/mobilesync/backup") { return .backups }

        // ── General categories ─────────────────────────────────────────────────
        if lower.contains("/applications/") { return .applications }
        if lower.contains("/downloads/") { return .downloads }
        if lower.contains("/documents/") { return .documents }
        if lower.contains("/movies/") || lower.contains("/music/")
            || lower.contains("/pictures/") || lower.contains("/photos/") { return .media }

        return .generic
    }

    /// Convenience overload taking a StorageItem.
    public func categorize(_ item: StorageItem) -> StorageCategory {
        return categorize(path: item.path)
    }

    // MARK: - Private helpers

    private func containsComponent(_ path: String, _ component: String) -> Bool {
        path.contains("/\(component)/") || path.hasSuffix("/\(component)")
            || path.contains("/\(component).") || path == component
    }
}
