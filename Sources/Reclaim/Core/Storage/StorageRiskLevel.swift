// StorageRiskLevel.swift
// Core/Storage
//
// Represents the safety classification of a detected storage item.
// Every displayed item must have an explicit risk level.
// UNKNOWN must never be included in automatic cleanup.

/// Risk classification applied to every detected storage item.
///
/// The classification is determined entirely by deterministic analyzers
/// and explicit safety rules — never by an LLM or heuristic guess.
public enum StorageRiskLevel: String, Codable, CaseIterable, Sendable, Hashable {

    /// Known cache or build artifact with a deterministic regeneration
    /// mechanism and no persistent user data expected.
    case safe

    /// Regeneratable, but may take time or require a network connection.
    case low

    /// Requires user review; impact is non-trivial but recoverable.
    case medium

    /// Significant impact expected; requires explicit user confirmation.
    case high

    /// System or credential path — must never be a cleanup candidate.
    case protected

    /// Analyzer could not classify the item. Defaults to review-required.
    /// Must never be included in automatic cleanup.
    case unknown

    // MARK: - Display helpers

    /// Human-readable label shown in the UI.
    public var displayLabel: String {
        switch self {
        case .safe:      return "SAFE"
        case .low:       return "LOW"
        case .medium:    return "MEDIUM"
        case .high:      return "HIGH"
        case .protected: return "PROTECTED"
        case .unknown:   return "UNKNOWN"
        }
    }

    /// Accessibility icon prefix so risk is never represented by colour alone.
    /// PRD §53: use icon + label + colour.
    public var accessibilityIcon: String {
        switch self {
        case .safe:      return "✓"
        case .low:       return "!"
        case .medium:    return "▲"
        case .high:      return "⚠"
        case .protected: return "🔒"
        case .unknown:   return "?"
        }
    }

    /// Whether this risk level permits inclusion in an automatic reclaim plan.
    /// HIGH and UNKNOWN require explicit user opt-in.
    public var isEligibleForAutomaticPlan: Bool {
        switch self {
        case .safe, .low, .medium: return true
        case .high, .protected, .unknown: return false
        }
    }
}
