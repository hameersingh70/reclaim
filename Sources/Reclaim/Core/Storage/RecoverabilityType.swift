// RecoverabilityType.swift
// Core/Storage
//
// Describes how (and whether) a storage item can be recreated after removal.
// Used by the Reclaim Planner to explain consequences and by the cleanup
// receipt to surface recovery instructions.

/// Describes how a storage item can be recovered if it is removed.
public enum RecoverabilityType: String, Codable, CaseIterable, Sendable, Hashable {

    /// Can be downloaded again from a remote source (e.g. SDK runtime,
    /// Homebrew formula download, npm registry package).
    case redownloadable

    /// Can be rebuilt by the owning tool from source inputs
    /// (e.g. Xcode DerivedData, Gradle build output).
    case rebuildable

    /// Can be regenerated automatically without user action
    /// (e.g. npm cache, Gradle dependency cache — restored on next build).
    case regeneratable

    /// Contains application runtime state; removal resets state but does
    /// not permanently lose user data.
    case applicationState

    /// Contains user-authored documents or irreplaceable data.
    /// Must never be automatically classified as safe.
    case userData

    /// macOS system data — requires OS-level mechanisms to restore.
    case systemData

    /// The analyzer could not determine recoverability.
    /// Treated conservatively: requires explicit user review.
    case unknown

    // MARK: - Display helpers

    public var displayLabel: String {
        switch self {
        case .redownloadable:   return "Re-downloadable"
        case .rebuildable:      return "Rebuildable"
        case .regeneratable:    return "Regeneratable"
        case .applicationState: return "Application State"
        case .userData:         return "User Data"
        case .systemData:       return "System Data"
        case .unknown:          return "Unknown"
        }
    }

    /// Whether cleanup of this item requires the user to take a manual
    /// recovery action (as opposed to being automatic).
    public var requiresManualRecovery: Bool {
        switch self {
        case .redownloadable, .rebuildable: return true
        case .regeneratable, .applicationState: return false
        case .userData, .systemData, .unknown: return true
        }
    }
}
