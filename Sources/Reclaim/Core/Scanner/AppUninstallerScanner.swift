// AppUninstallerScanner.swift
// Reclaim/Core/Scanner
//
// High-performance Application Uninstaller and Leftover Scanner.
// Discovers installed macOS applications and associated leftover files
// across ~/Library/Application Support, ~/Library/Caches, ~/Library/Preferences,
// ~/Library/Containers, and identifies orphaned leftovers from deleted apps.

import Foundation
import AppKit

// MARK: - Models

public enum LeftoverCategory: String, Sendable, CaseIterable {
    case applicationSupport = "Application Support"
    case caches = "Caches"
    case preferences = "Preferences"
    case savedState = "Saved State"
    case container = "Container"
    case logs = "Logs"
    case launchAgents = "Launch Agent"
    case httpStorages = "HTTP Storages"
    case webKit = "WebKit Cache"
    case other = "Other"
}

public struct AppLeftoverItem: Identifiable, Sendable {
    public let id: String
    public let path: String
    public let category: LeftoverCategory
    public let size: Int64
    public let isDir: Bool

    public init(id: String = UUID().uuidString, path: String, category: LeftoverCategory, size: Int64, isDir: Bool) {
        self.id = id
        self.path = path
        self.category = category
        self.size = size
        self.isDir = isDir
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

public struct AppItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let bundleURL: URL? // nil if orphan leftover
    public let bundleIdentifier: String
    public let version: String
    public let appSize: Int64
    public var leftovers: [AppLeftoverItem]
    public let isRunning: Bool
    public let isOrphan: Bool

    public init(
        id: String,
        name: String,
        bundleURL: URL?,
        bundleIdentifier: String,
        version: String,
        appSize: Int64,
        leftovers: [AppLeftoverItem] = [],
        isRunning: Bool = false,
        isOrphan: Bool = false
    ) {
        self.id = id
        self.name = name
        self.bundleURL = bundleURL
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.appSize = appSize
        self.leftovers = leftovers
        self.isRunning = isRunning
        self.isOrphan = isOrphan
    }

    public var totalSize: Int64 {
        appSize + leftovers.reduce(0) { $0 + $1.size }
    }

    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    public var formattedAppSize: String {
        ByteCountFormatter.string(fromByteCount: appSize, countStyle: .file)
    }

    public var leftoversSize: Int64 {
        leftovers.reduce(0) { $0 + $1.size }
    }

    public var formattedLeftoversSize: String {
        ByteCountFormatter.string(fromByteCount: leftoversSize, countStyle: .file)
    }
}

// MARK: - Thread-Safe Primitives

final class ProtectedArray<T>: @unchecked Sendable {
    private var items: [T] = []
    private let lock = NSLock()

    func append(_ item: T) {
        lock.lock()
        items.append(item)
        lock.unlock()
    }

    var values: [T] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }
}

final class ProtectedDictionary<Key: Hashable, Value>: @unchecked Sendable {
    private var dict: [Key: Value] = [:]
    private let lock = NSLock()

    func mutate(_ block: (inout [Key: Value]) -> Void) {
        lock.lock()
        block(&dict)
        lock.unlock()
    }

    var snapshot: [Key: Value] {
        lock.lock()
        defer { lock.unlock() }
        return dict
    }
}

// MARK: - Scanner

public final class AppUninstallerScanner: @unchecked Sendable {
    public let homeURL: URL
    public let fileManager: FileManager

    public init(
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) {
        self.homeURL = homeURL
        self.fileManager = fileManager
    }

    /// Scans installed applications and maps their corresponding leftovers.
    /// Runs parallel multi-core analysis for blazing fast execution.
    public func scanInstalledApps(includeSystemApps: Bool = false) -> [AppItem] {
        var appDirs = [
            URL(fileURLWithPath: "/Applications"),
            homeURL.appendingPathComponent("Applications")
        ]
        if includeSystemApps {
            appDirs.append(URL(fileURLWithPath: "/System/Applications"))
        }

        var discoveredURLs: [URL] = []
        for dir in appDirs {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.localizedNameKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            discoveredURLs.append(contentsOf: contents.filter { $0.pathExtension == "app" })
        }

        let runningApps = NSWorkspace.shared.runningApplications
        let runningBundleIDs = Set(runningApps.compactMap { $0.bundleIdentifier?.lowercased() })

        let targetURLs = discoveredURLs
        let protectedApps = ProtectedArray<AppItem>()

        DispatchQueue.concurrentPerform(iterations: targetURLs.count) { idx in
            let appURL = targetURLs[idx]
            let bundle = Bundle(url: appURL)
            let bundleID = bundle?.bundleIdentifier ?? ""
            let name = (try? appURL.resourceValues(forKeys: [.localizedNameKey]))?.localizedName
                ?? appURL.deletingPathExtension().lastPathComponent
            let version = bundle?.infoDictionary?["CFBundleShortVersionString"] as? String
                ?? bundle?.infoDictionary?["CFBundleVersion"] as? String
                ?? "1.0"

            let appSize = FileScanner.calculateDirectorySize(at: appURL.path).allocatedBytes
            let isRunning = !bundleID.isEmpty && runningBundleIDs.contains(bundleID.lowercased())
            let leftovers = self.findLeftovers(forAppName: name, bundleIdentifier: bundleID)

            let appItem = AppItem(
                id: appURL.path,
                name: name,
                bundleURL: appURL,
                bundleIdentifier: bundleID,
                version: version,
                appSize: appSize,
                leftovers: leftovers,
                isRunning: isRunning,
                isOrphan: false
            )

            protectedApps.append(appItem)
        }

        var apps = protectedApps.values
        apps.sort { $0.totalSize > $1.totalSize }
        return apps
    }

    /// Discovers orphaned leftovers (app support, caches, preferences) left behind by apps that no longer exist.
    public func scanOrphanLeftovers(knownApps: [AppItem]) -> [AppItem] {
        let knownNames = Set(knownApps.map { $0.name.lowercased() })
        let knownBundleIDs = Set(knownApps.map { $0.bundleIdentifier.lowercased() }.filter { !$0.isEmpty })

        let libraryURL = homeURL.appendingPathComponent("Library")
        let candidateLocations: [(URL, LeftoverCategory)] = [
            (libraryURL.appendingPathComponent("Application Support"), .applicationSupport),
            (libraryURL.appendingPathComponent("Caches"), .caches),
            (libraryURL.appendingPathComponent("Saved Application State"), .savedState),
            (libraryURL.appendingPathComponent("Containers"), .container),
            (libraryURL.appendingPathComponent("HTTPStorages"), .httpStorages),
            (libraryURL.appendingPathComponent("WebKit"), .webKit),
            (libraryURL.appendingPathComponent("Logs"), .logs),
            (libraryURL.appendingPathComponent("LaunchAgents"), .launchAgents)
        ]

        let protectedOrphans = ProtectedDictionary<String, [AppLeftoverItem]>()

        // Ignore standard Apple & system folders that are never orphans
        let systemExclusions: Set<String> = [
            "apple", "system", "macos", "safari", "mail", "cloudkit", "finder", "dock",
            "messages", "photos", "quicklook", "siri", "spotlight", "addressbook", "calendars",
            "accounts", "syncservices", "keychains", "identityservices", "group containers",
            "audiomodes", "fontcollections", "input methods", "keyboard layouts", "services"
        ]

        for (folderURL, category) in candidateLocations {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            let filtered = contents.filter { itemURL in
                let itemLower = itemURL.lastPathComponent.lowercased()
                if systemExclusions.contains(itemLower) || itemLower.hasPrefix("com.apple.") {
                    return false
                }
                let matchesInstalled = knownNames.contains(itemLower) ||
                    knownBundleIDs.contains(itemLower) ||
                    knownNames.contains(where: { itemLower.contains($0) && $0.count >= 4 }) ||
                    knownBundleIDs.contains(where: { itemLower.hasPrefix($0) })
                return !matchesInstalled
            }

            let targetItems = filtered

            DispatchQueue.concurrentPerform(iterations: targetItems.count) { idx in
                let itemURL = targetItems[idx]
                let itemName = itemURL.lastPathComponent
                var isDir: ObjCBool = false
                guard self.fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir) else { return }

                let size: Int64
                if isDir.boolValue {
                    size = FileScanner.calculateDirectorySize(at: itemURL.path).allocatedBytes
                } else {
                    var st = stat()
                    size = (lstat(itemURL.path, &st) == 0) ? Int64(st.st_blocks) * 512 : 0
                }

                // Only surface meaningful leftovers (>= 1MB)
                if size >= 1_000_000 {
                    let displayName = itemName
                        .replacingOccurrences(of: ".savedState", with: "")
                        .replacingOccurrences(of: "com.", with: "")
                    let leftover = AppLeftoverItem(
                        path: itemURL.path,
                        category: category,
                        size: size,
                        isDir: isDir.boolValue
                    )
                    protectedOrphans.mutate { $0[displayName, default: []].append(leftover) }
                }
            }
        }

        var orphanApps: [AppItem] = []
        for (name, items) in protectedOrphans.snapshot {
            let item = AppItem(
                id: "orphan:\(name)",
                name: name.capitalized,
                bundleURL: nil,
                bundleIdentifier: "",
                version: "Uninstalled",
                appSize: 0,
                leftovers: items,
                isRunning: false,
                isOrphan: true
            )
            orphanApps.append(item)
        }

        orphanApps.sort { $0.totalSize > $1.totalSize }
        return orphanApps
    }

    /// Finds leftover files for an installed application.
    public func findLeftovers(forAppName name: String, bundleIdentifier: String) -> [AppLeftoverItem] {
        var leftovers: [AppLeftoverItem] = []
        let libraryURL = homeURL.appendingPathComponent("Library")

        let targets: [(URL, LeftoverCategory, [String])] = [
            (
                libraryURL.appendingPathComponent("Application Support"),
                .applicationSupport,
                [name, bundleIdentifier]
            ),
            (
                libraryURL.appendingPathComponent("Caches"),
                .caches,
                [bundleIdentifier, name]
            ),
            (
                libraryURL.appendingPathComponent("Preferences"),
                .preferences,
                ["\(bundleIdentifier).plist"]
            ),
            (
                libraryURL.appendingPathComponent("Saved Application State"),
                .savedState,
                ["\(bundleIdentifier).savedState"]
            ),
            (
                libraryURL.appendingPathComponent("Containers"),
                .container,
                [bundleIdentifier]
            ),
            (
                libraryURL.appendingPathComponent("Group Containers"),
                .container,
                ["group.\(bundleIdentifier)", bundleIdentifier]
            ),
            (
                libraryURL.appendingPathComponent("HTTPStorages"),
                .httpStorages,
                [bundleIdentifier]
            ),
            (
                libraryURL.appendingPathComponent("WebKit"),
                .webKit,
                [bundleIdentifier]
            ),
            (
                libraryURL.appendingPathComponent("Logs"),
                .logs,
                [name, bundleIdentifier]
            ),
            (
                libraryURL.appendingPathComponent("LaunchAgents"),
                .launchAgents,
                ["\(bundleIdentifier).plist"]
            ),
            (
                URL(fileURLWithPath: "/Library/LaunchAgents"),
                .launchAgents,
                ["\(bundleIdentifier).plist"]
            ),
            (
                URL(fileURLWithPath: "/Library/Application Support"),
                .applicationSupport,
                [name]
            )
        ]

        for (baseURL, category, searchNames) in targets {
            for searchName in searchNames where !searchName.isEmpty {
                let candidateURL = baseURL.appendingPathComponent(searchName)
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: candidateURL.path, isDirectory: &isDir) {
                    let size: Int64
                    if isDir.boolValue {
                        size = FileScanner.calculateDirectorySize(at: candidateURL.path).allocatedBytes
                    } else {
                        var st = stat()
                        size = (lstat(candidateURL.path, &st) == 0) ? Int64(st.st_blocks) * 512 : 0
                    }

                    if size > 0 && !leftovers.contains(where: { $0.path == candidateURL.path }) {
                        leftovers.append(AppLeftoverItem(
                            path: candidateURL.path,
                            category: category,
                            size: size,
                            isDir: isDir.boolValue
                        ))
                    }
                }
            }
        }

        return leftovers
    }

    /// Safely uninstalls the application and moves all selected leftovers to macOS Trash.
    @discardableResult
    public func uninstall(app: AppItem, deleteLeftovers: Bool = true) throws -> Int64 {
        var totalReclaimed: Int64 = 0

        // 1. Move App Bundle to Trash
        if let bundleURL = app.bundleURL, fileManager.fileExists(atPath: bundleURL.path) {
            // Cannot delete protected system apps in /System
            if bundleURL.path.hasPrefix("/System/") {
                throw NSError(domain: "ReclaimSafety", code: 403, userInfo: [NSLocalizedDescriptionKey: "System applications in /System cannot be uninstalled."])
            }
            try fileManager.trashItem(at: bundleURL, resultingItemURL: nil)
            totalReclaimed += app.appSize
        }

        // 2. Move Leftovers to Trash
        if deleteLeftovers {
            for leftover in app.leftovers {
                let url = URL(fileURLWithPath: leftover.path)
                if fileManager.fileExists(atPath: leftover.path) {
                    try? fileManager.trashItem(at: url, resultingItemURL: nil)
                    totalReclaimed += leftover.size
                }
            }
        }

        return totalReclaimed
    }
}
