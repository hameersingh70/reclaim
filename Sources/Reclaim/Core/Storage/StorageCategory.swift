// StorageCategory.swift
// Core/Storage
//
// Top-level grouping of storage items shown in the Dashboard and sidebar.
// Covers the full spectrum: standard developer, AI/ML engineer, data scientist,
// software engineer, and general power user.

/// Top-level storage category shown in the main Dashboard and sidebar.
public enum StorageCategory: String, Codable, CaseIterable, Sendable, Hashable {

    // ── Developer Ecosystems ──────────────────────────────────────
    case docker
    case xcode
    case android
    case gradle
    case maven
    case node
    case homebrew
    case ruby           // rbenv, rvm, gems
    case jvm            // old JDK installations, Java runtimes
    case rust           // cargo target, registry

    // ── AI / ML / Data Science ────────────────────────────────────
    case llm            // Ollama, LM Studio, GGUF, Hugging Face large models
    case mlFrameworks   // PyTorch cache, TensorFlow, CoreML, ONNX weights
    case pythonEnv      // conda, pyenv, pip cache, virtualenv, tox

    // ── System & User Cleanup ─────────────────────────────────────
    case backups        // iPhone/iPad backups, Time Machine local snapshots
    case media          // large video, disk images (.dmg), archives

    // ── General categories ────────────────────────────────────────
    case applications
    case documents
    case downloads
    case systemOther

    /// Catch-all for items no analyzer has claimed.
    case generic

    // MARK: - Display helpers

    public var displayName: String {
        switch self {
        case .docker:       return "Docker"
        case .xcode:        return "Xcode"
        case .android:      return "Android"
        case .gradle:       return "Gradle"
        case .maven:        return "Maven"
        case .node:         return "Node.js"
        case .homebrew:     return "Homebrew"
        case .ruby:         return "Ruby"
        case .jvm:          return "JVM / Java"
        case .rust:         return "Rust / Cargo"
        case .llm:          return "LLM Models"
        case .mlFrameworks: return "ML Frameworks"
        case .pythonEnv:    return "Python Envs"
        case .backups:      return "Backups"
        case .media:        return "Large Media"
        case .applications: return "Applications"
        case .documents:    return "Documents"
        case .downloads:    return "Downloads"
        case .systemOther:  return "System / Other"
        case .generic:      return "Other"
        }
    }

    /// Whether this category belongs to the Developer / AI storage sections.
    public var isDeveloperCategory: Bool {
        switch self {
        case .docker, .xcode, .android, .gradle, .maven, .node,
             .homebrew, .ruby, .jvm, .rust, .llm, .mlFrameworks, .pythonEnv:
            return true
        default:
            return false
        }
    }

    /// Whether this category belongs to the AI / ML section.
    public var isAICategory: Bool {
        switch self {
        case .llm, .mlFrameworks, .pythonEnv: return true
        default: return false
        }
    }
}
