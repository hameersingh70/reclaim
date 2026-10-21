// LaunchAgentsManager.swift
// Reclaim/Core/Daemons
//
// Native macOS LaunchAgents & Background Daemons Manager.
// Discovers background daemons in ~/Library/LaunchAgents, /Library/LaunchAgents,
// and /Library/LaunchDaemons. Identifies developer background services (PostgreSQL,
// Redis, Ollama, Docker, MySQL, Homebrew) and flags orphaned or dead plists.

import Foundation

public enum LaunchAgentScope: String, Sendable, CaseIterable {
    case userAgents = "User Agents (~/Library/LaunchAgents)"
    case systemAgents = "System Agents (/Library/LaunchAgents)"
    case systemDaemons = "System Daemons (/Library/LaunchDaemons)"

    public var directoryURL: URL {
        switch self {
        case .userAgents:
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
        case .systemAgents:
            return URL(fileURLWithPath: "/Library/LaunchAgents")
        case .systemDaemons:
            return URL(fileURLWithPath: "/Library/LaunchDaemons")
        }
    }
}

public enum LaunchAgentCategory: String, Sendable, CaseIterable {
    case developer = "Developer Service"
    case application = "App Background Service"
    case orphan = "Orphaned / Missing Binary"
    case system = "System / Other"
}

public struct LaunchAgentItem: Identifiable, Sendable {
    public let id: String
    public let label: String
    public let plistPath: String
    public let scope: LaunchAgentScope
    public let category: LaunchAgentCategory
    public let programArguments: [String]
    public let executablePath: String?
    public let runAtLoad: Bool
    public let keepAlive: Bool
    public var isRunning: Bool
    public var pid: Int32?
    public let isOrphan: Bool

    public init(
        id: String,
        label: String,
        plistPath: String,
        scope: LaunchAgentScope,
        category: LaunchAgentCategory,
        programArguments: [String],
        executablePath: String?,
        runAtLoad: Bool,
        keepAlive: Bool,
        isRunning: Bool,
        pid: Int32?,
        isOrphan: Bool
    ) {
        self.id = id
        self.label = label
        self.plistPath = plistPath
        self.scope = scope
        self.category = category
        self.programArguments = programArguments
        self.executablePath = executablePath
        self.runAtLoad = runAtLoad
        self.keepAlive = keepAlive
        self.isRunning = isRunning
        self.pid = pid
        self.isOrphan = isOrphan
    }
}

public final class LaunchAgentsManager: @unchecked Sendable {
    public init() {}

    private static let developerKeywords: [String] = [
        "homebrew", "docker", "ollama", "postgres", "redis", "mysql",
        "mongodb", "jenkins", "nginx", "caddy", "node", "python",
        "elasticsearch", "rabbitmq", "simulator", "android", "adb",
        "minikube", "colima", "orbstack", "podman"
    ]

    /// Scans all configured launch agent scopes and correlates with `launchctl list`
    public func scan() -> [LaunchAgentItem] {
        let runningServices = fetchRunningServices()
        var results: [LaunchAgentItem] = []

        for scope in LaunchAgentScope.allCases {
            let dir = scope.directoryURL
            guard FileManager.default.fileExists(atPath: dir.path),
                  let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
                continue
            }

            for file in files where file.hasSuffix(".plist") {
                let fullPath = dir.appendingPathComponent(file).path
                if let item = parsePlist(at: fullPath, scope: scope, runningServices: runningServices) {
                    results.append(item)
                }
            }
        }

        return results.sorted { (a, b) -> Bool in
            if a.isRunning != b.isRunning { return a.isRunning }
            return a.label.lowercased() < b.label.lowercased()
        }
    }

    /// Toggles a service state using launchctl
    public func setEnabled(item: LaunchAgentItem, enable: Bool) -> (success: Bool, message: String) {
        let cmd = enable ? "load" : "unload"
        let res = runProcess("/bin/launchctl", arguments: [cmd, item.plistPath])
        if res.exitCode == 0 {
            return (true, "Successfully \(enable ? "loaded" : "unloaded") \(item.label).")
        } else {
            return (false, "launchctl \(cmd) failed: \(res.output)")
        }
    }

    /// Safely moves a launch agent plist to Trash
    public func trash(item: LaunchAgentItem) -> (success: Bool, message: String) {
        if item.isRunning {
            _ = setEnabled(item: item, enable: false)
        }

        let fileURL = URL(fileURLWithPath: item.plistPath)
        do {
            try FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
            return (true, "Moved \(fileURL.lastPathComponent) to ~/.Trash.")
        } catch {
            return (false, "Could not trash plist: \(error.localizedDescription)")
        }
    }

    // MARK: - Parsing Helpers

    private func parsePlist(at path: String, scope: LaunchAgentScope, runningServices: [String: Int32?]) -> LaunchAgentItem? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }

        let label = (plist["Label"] as? String) ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let runAtLoad = (plist["RunAtLoad"] as? Bool) ?? false
        let keepAlive = (plist["KeepAlive"] as? Bool) ?? false

        var programArguments: [String] = []
        if let args = plist["ProgramArguments"] as? [String] {
            programArguments = args
        } else if let prog = plist["Program"] as? String {
            programArguments = [prog]
        }

        let executable = programArguments.first ?? (plist["Program"] as? String)
        let isOrphan: Bool
        if let exec = executable, !exec.isEmpty {
            let actualPath = (exec as NSString).expandingTildeInPath
            isOrphan = !FileManager.default.fileExists(atPath: actualPath)
        } else {
            isOrphan = false
        }

        let isRunning: Bool
        let pid: Int32?
        if let found = runningServices[label] {
            isRunning = true
            pid = found
        } else {
            isRunning = false
            pid = nil
        }

        // Categorize
        let lowerLabel = label.lowercased()
        let lowerExec = (executable ?? "").lowercased()
        let category: LaunchAgentCategory

        if isOrphan {
            category = .orphan
        } else if Self.developerKeywords.contains(where: { lowerLabel.contains($0) || lowerExec.contains($0) }) {
            category = .developer
        } else if lowerLabel.hasPrefix("com.apple.") {
            category = .system
        } else {
            category = .application
        }

        return LaunchAgentItem(
            id: "\(scope.rawValue):\(label)",
            label: label,
            plistPath: path,
            scope: scope,
            category: category,
            programArguments: programArguments,
            executablePath: executable,
            runAtLoad: runAtLoad,
            keepAlive: keepAlive,
            isRunning: isRunning,
            pid: pid,
            isOrphan: isOrphan
        )
    }

    private func fetchRunningServices() -> [String: Int32?] {
        let res = runProcess("/bin/launchctl", arguments: ["list"])
        guard res.exitCode == 0 else { return [:] }

        var map: [String: Int32?] = [:]
        let lines = res.output.components(separatedBy: "\n")
        for line in lines.dropFirst() {
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 3 else { continue }
            let pidStr = parts[0].trimmingCharacters(in: .whitespaces)
            let label = parts[2].trimmingCharacters(in: .whitespaces)

            let pid = Int32(pidStr)
            map[label] = pid
        }
        return map
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
