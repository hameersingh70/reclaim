// DeveloperTweaksEngine.swift
// Reclaim/Core/Tweaks
//
// Native macOS developer system tweaks & hidden defaults engine.
// Configures developer-friendly macOS defaults: hidden files visibility,
// full POSIX path in Finder, disabling .DS_Store creation on network shares,
// Dock animation acceleration, and Xcode build timing.

import Foundation

public enum TweakCategory: String, Sendable, CaseIterable {
    case finder = "Finder & File System"
    case dock = "Dock & Mission Control"
    case developer = "Developer Tools"
}

public struct DeveloperTweakItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let category: TweakCategory
    public let domain: String
    public let key: String
    public let valueType: TweakValueType
    public let enabledValue: String
    public let disabledValue: String
    public let restartService: String? // e.g. "Finder", "Dock"
    public var isEnabled: Bool

    public init(
        id: String,
        title: String,
        description: String,
        category: TweakCategory,
        domain: String,
        key: String,
        valueType: TweakValueType = .boolean,
        enabledValue: String = "true",
        disabledValue: String = "false",
        restartService: String? = nil,
        isEnabled: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.domain = domain
        self.key = key
        self.valueType = valueType
        self.enabledValue = enabledValue
        self.disabledValue = disabledValue
        self.restartService = restartService
        self.isEnabled = isEnabled
    }
}

public enum TweakValueType: String, Sendable {
    case boolean = "bool"
    case float = "float"
    case integer = "int"
    case string = "string"
}

public final class DeveloperTweaksEngine: @unchecked Sendable {
    public init() {}

    /// Predefined catalog of developer macOS tweaks
    public static let standardTweaks: [DeveloperTweakItem] = [
        DeveloperTweakItem(
            id: "finder.showHiddenFiles",
            title: "Show Hidden Files & Folders",
            description: "Forces Finder to display hidden dotfiles (.git, .env, .zshrc) by default.",
            category: .finder,
            domain: "com.apple.finder",
            key: "AppleShowAllFiles",
            valueType: .boolean,
            enabledValue: "true",
            disabledValue: "false",
            restartService: "Finder"
        ),
        DeveloperTweakItem(
            id: "finder.showAllExtensions",
            title: "Show All File Extensions",
            description: "Always display file extensions (.json, .swift, .sh) in Finder.",
            category: .finder,
            domain: "NSGlobalDomain",
            key: "AppleShowAllExtensions",
            valueType: .boolean,
            enabledValue: "true",
            disabledValue: "false",
            restartService: "Finder"
        ),
        DeveloperTweakItem(
            id: "finder.showPosixPath",
            title: "Show Full POSIX Path in Window Title",
            description: "Displays the absolute file system path in the Finder window title bar.",
            category: .finder,
            domain: "com.apple.finder",
            key: "_FXShowPosixPathInTitle",
            valueType: .boolean,
            enabledValue: "true",
            disabledValue: "false",
            restartService: "Finder"
        ),
        DeveloperTweakItem(
            id: "finder.disableNetworkDSStore",
            title: "Disable .DS_Store on Network Shares",
            description: "Prevents macOS from polluting remote SMB/NFS mounted drives with .DS_Store files.",
            category: .finder,
            domain: "com.apple.desktopservices",
            key: "DSDontWriteNetworkStores",
            valueType: .boolean,
            enabledValue: "true",
            disabledValue: "false"
        ),
        DeveloperTweakItem(
            id: "finder.disableUSBDSStore",
            title: "Disable .DS_Store on USB Drives",
            description: "Prevents macOS from creating hidden .DS_Store files on removable flash drives.",
            category: .finder,
            domain: "com.apple.desktopservices",
            key: "DSDontWriteUSBStores",
            valueType: .boolean,
            enabledValue: "true",
            disabledValue: "false"
        ),
        DeveloperTweakItem(
            id: "finder.expandedSavePanel",
            title: "Always Expand Save Dialogs",
            description: "Expands the file save panel by default instead of showing the collapsed picker.",
            category: .finder,
            domain: "NSGlobalDomain",
            key: "NSNavPanelExpandedStateForSaveMode",
            valueType: .boolean,
            enabledValue: "true",
            disabledValue: "false"
        ),
        DeveloperTweakItem(
            id: "dock.instantAutoHide",
            title: "Remove Dock Auto-Hide Delay",
            description: "Eliminates the default hover delay before the Dock slides into view.",
            category: .dock,
            domain: "com.apple.dock",
            key: "autohide-delay",
            valueType: .float,
            enabledValue: "0",
            disabledValue: "0.5",
            restartService: "Dock"
        ),
        DeveloperTweakItem(
            id: "dock.fastAnimation",
            title: "Accelerate Dock Slide Animation",
            description: "Speeds up the Dock sliding animation duration from 1s to 0.15s.",
            category: .dock,
            domain: "com.apple.dock",
            key: "autohide-time-modifier",
            valueType: .float,
            enabledValue: "0.15",
            disabledValue: "1.0",
            restartService: "Dock"
        ),
        DeveloperTweakItem(
            id: "xcode.buildDuration",
            title: "Show Xcode Build Elapsed Time",
            description: "Displays the build duration (e.g. 'Build Succeeded in 4.2s') in Xcode's activity bezel.",
            category: .developer,
            domain: "com.apple.dt.Xcode",
            key: "ShowBuildOperationDuration",
            valueType: .boolean,
            enabledValue: "true",
            disabledValue: "false"
        )
    ]

    /// Reads current state of all standard tweaks
    public func loadTweaks() -> [DeveloperTweakItem] {
        return Self.standardTweaks.map { tweak in
            var item = tweak
            item.isEnabled = checkTweakStatus(tweak: tweak)
            return item
        }
    }

    /// Checks if a specific tweak is active
    public func checkTweakStatus(tweak: DeveloperTweakItem) -> Bool {
        let res = runProcess("/usr/bin/defaults", arguments: ["read", tweak.domain, tweak.key])
        guard res.exitCode == 0 else { return false }
        let trimmed = res.output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch tweak.valueType {
        case .boolean:
            return trimmed == "1" || trimmed == "true" || trimmed == "yes"
        case .float, .integer:
            if let current = Float(trimmed), let target = Float(tweak.enabledValue) {
                return abs(current - target) < 0.01
            }
            return trimmed == tweak.enabledValue.lowercased()
        case .string:
            return trimmed == tweak.enabledValue.lowercased()
        }
    }

    /// Sets the state of a tweak and optionally restarts the affected service
    @discardableResult
    public func setTweak(_ tweak: DeveloperTweakItem, enabled: Bool, restartIfRequired: Bool = true) -> Bool {
        let targetValue = enabled ? tweak.enabledValue : tweak.disabledValue
        let typeFlag: String
        switch tweak.valueType {
        case .boolean: typeFlag = "-bool"
        case .float: typeFlag = "-float"
        case .integer: typeFlag = "-int"
        case .string: typeFlag = "-string"
        }

        let writeRes = runProcess("/usr/bin/defaults", arguments: ["write", tweak.domain, tweak.key, typeFlag, targetValue])
        guard writeRes.exitCode == 0 else { return false }

        if restartIfRequired, let service = tweak.restartService {
            restartServiceByName(service)
        }
        return true
    }

    /// Prune Xcode unavailable simulator runtimes
    public func pruneUnavailableSimulators() -> (success: Bool, message: String) {
        let res = runProcess("/usr/bin/xcrun", arguments: ["simctl", "delete", "unavailable"])
        if res.exitCode == 0 {
            return (true, "Pruned unavailable simulator runtimes and device caches.")
        } else {
            return (false, res.output.isEmpty ? "No unavailable simulators found or Xcode command-line tools not set." : res.output)
        }
    }

    public func restartServiceByName(_ service: String) {
        _ = runProcess("/usr/bin/killall", arguments: [service])
    }

    private func runProcess(_ executable: String, arguments: [String]) -> (exitCode: Int32, output: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = arguments
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do {
            try p.run()
            p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let str = String(data: data, encoding: .utf8) ?? ""
            return (p.terminationStatus, str)
        } catch {
            return (-1, error.localizedDescription)
        }
    }
}
