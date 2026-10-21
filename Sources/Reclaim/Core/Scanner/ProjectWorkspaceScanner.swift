// ProjectWorkspaceScanner.swift
// Core/Scanner
//
// High-performance scanner that crawls developer project workspaces to discover
// project-level `node_modules` directories and Python virtual environments (`.venv`, `venv`, `env`).
//
// Key performance & safety features:
// - Never descends into `node_modules` or virtualenvs: treats them as atomic single units.
// - Skips `.git`, `.svn`, `.hg`, `.build`, and hidden build caches.
// - Fast APFS block calculation via FileScanner.calculateDirectorySize.
// - Automatically inspects parent directory for package.json / lockfiles / pyproject.toml / requirements.txt.

import Foundation

public struct ProjectWorkspaceScanner: Sendable {

    /// Standard candidate workspace roots where developers keep repositories on macOS
    public static func defaultWorkspaceRoots(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        let candidates = [
            home.appendingPathComponent("Documents/GitHub"),
            home.appendingPathComponent("GitHub"),
            home.appendingPathComponent("Developer"),
            home.appendingPathComponent("Projects"),
            home.appendingPathComponent("Workspace"),
            home.appendingPathComponent("workspace"),
            home.appendingPathComponent("Code"),
            home.appendingPathComponent("code"),
            home.appendingPathComponent("src"),
            home.appendingPathComponent("dev"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents"),
        ]
        return candidates.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Crawls the given workspace roots up to maxDepth and yields discovered `node_modules`,
    /// Python virtual environments, Rust `target/`, and SwiftPM `.build/` as atomic `StorageItem` records.
    public static func scanWorkspaces(
        roots: [URL],
        scanNode: Bool = true,
        scanPython: Bool = true,
        scanRust: Bool = true,
        scanSwift: Bool = true,
        maxDepth: Int = 4,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) -> [StorageItem] {
        var discovered: [StorageItem] = []
        let fileManager = FileManager.default

        // Directories to strictly prune / never descend into
        let pruneDirNames: Set<String> = [
            ".git", ".svn", ".hg", ".trash", "Caches", "Library", "System",
            "Applications", ".npm", ".gradle", ".cargo", "DerivedData"
        ]

        for root in roots {
            guard fileManager.fileExists(atPath: root.path) else { continue }
            onProgress?("Scanning workspace: \(root.lastPathComponent)...")

            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                options: [.skipsPackageDescendants]
            ) else { continue }

            while let fileURL = enumerator.nextObject() as? URL {
                let dirName = fileURL.lastPathComponent

                // Skip pruning directories
                if pruneDirNames.contains(dirName) {
                    enumerator.skipDescendants()
                    continue
                }

                if enumerator.level > maxDepth {
                    enumerator.skipDescendants()
                    continue
                }

                let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                guard isDirectory else { continue }

                // 1. Check for `node_modules`
                if scanNode && dirName == "node_modules" {
                    enumerator.skipDescendants() // Crucial: never crawl inside node_modules!
                    
                    let path = fileURL.path
                    let parentURL = fileURL.deletingLastPathComponent()
                    let projectName = parentURL.lastPathComponent
                    
                    // Fast APFS size calculation
                    let calc = FileScanner.calculateDirectorySize(at: path)
                    guard calc.allocatedBytes > 0 else { continue }

                    // Lockfile check in project root
                    let lockfiles = ["package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb"]
                    var hasLockfile = false
                    for lock in lockfiles {
                        if fileManager.fileExists(atPath: parentURL.appendingPathComponent(lock).path) {
                            hasLockfile = true
                            break
                        }
                    }

                    var item = StorageItem(
                        path: path,
                        logicalSize: calc.allocatedBytes,
                        allocatedSize: calc.allocatedBytes,
                        category: .node,
                        risk: hasLockfile ? .low : .medium,
                        recoverability: .rebuildable,
                        whatIsThis: "\(projectName)/node_modules — Project Dependencies"
                    )
                    item.whyItExists = "Installed third-party JavaScript/TypeScript packages for \(projectName) (\(calc.fileCount) files)."
                    item.removalConsequence = "Project cannot build or run until dependencies are reinstalled."
                    item.recoveryInstruction = hasLockfile ? "Reinstall with: npm install (or yarn / pnpm / bun install)" : "Verify package.json before reinstalling"
                    
                    discovered.append(item)
                    onProgress?("Found node_modules: \(projectName) (\(ByteCountFormatter.string(fromByteCount: calc.allocatedBytes, countStyle: .file)))")
                    continue
                }

                // 2. Check for Python virtual environments (.venv, venv, env)
                if scanPython && (dirName == ".venv" || dirName == "venv" || dirName == "env") {
                    // Verify this is an actual Python virtualenv (contains pyvenv.cfg or bin/python or bin/activate or lib/python*)
                    let hasPyvenvCfg = fileManager.fileExists(atPath: fileURL.appendingPathComponent("pyvenv.cfg").path)
                    let hasBinPython = fileManager.fileExists(atPath: fileURL.appendingPathComponent("bin/python").path) ||
                                       fileManager.fileExists(atPath: fileURL.appendingPathComponent("bin/activate").path)
                    let hasLib = fileManager.fileExists(atPath: fileURL.appendingPathComponent("lib").path)

                    if hasPyvenvCfg || (hasBinPython && hasLib) {
                        enumerator.skipDescendants() // Crucial: never crawl inside the venv!

                        let path = fileURL.path
                        let parentURL = fileURL.deletingLastPathComponent()
                        let projectName = parentURL.lastPathComponent

                        // Fast APFS size calculation
                        let calc = FileScanner.calculateDirectorySize(at: path)
                        guard calc.allocatedBytes > 0 else { continue }

                        let hasRequirements = fileManager.fileExists(atPath: parentURL.appendingPathComponent("requirements.txt").path) ||
                                              fileManager.fileExists(atPath: parentURL.appendingPathComponent("pyproject.toml").path) ||
                                              fileManager.fileExists(atPath: parentURL.appendingPathComponent("Pipfile").path)

                        var item = StorageItem(
                            path: path,
                            logicalSize: calc.allocatedBytes,
                            allocatedSize: calc.allocatedBytes,
                            category: .pythonEnv,
                            risk: .low,
                            recoverability: .rebuildable,
                            whatIsThis: "\(projectName)/\(dirName) — Python Virtual Environment"
                        )
                        item.whyItExists = "Isolated Python virtual environment and installed packages for \(projectName) (\(calc.fileCount) files)."
                        item.removalConsequence = "Project virtualenv will need to be recreated before running scripts."
                        item.recoveryInstruction = hasRequirements ?
                            "Recreate with: python3 -m venv \(dirName) && pip install -r requirements.txt" :
                            "Recreate with: python3 -m venv \(dirName)"

                        discovered.append(item)
                        onProgress?("Found Python venv: \(projectName)/\(dirName) (\(ByteCountFormatter.string(fromByteCount: calc.allocatedBytes, countStyle: .file)))")
                        continue
                    }
                }

                // 3. Check for Rust target build directories
                if scanRust && dirName == "target" {
                    let parentURL = fileURL.deletingLastPathComponent()
                    let cargoPath = parentURL.appendingPathComponent("Cargo.toml").path
                    if fileManager.fileExists(atPath: cargoPath) {
                        enumerator.skipDescendants() // Crucial: never crawl inside target!

                        let path = fileURL.path
                        let projectName = parentURL.lastPathComponent
                        let calc = FileScanner.calculateDirectorySize(at: path)
                        guard calc.allocatedBytes > 0 else { continue }

                        let hasLock = fileManager.fileExists(atPath: parentURL.appendingPathComponent("Cargo.lock").path)
                        var item = StorageItem(
                            path: path,
                            logicalSize: calc.allocatedBytes,
                            allocatedSize: calc.allocatedBytes,
                            category: .rust,
                            risk: hasLock ? .low : .medium,
                            recoverability: .rebuildable,
                            whatIsThis: "\(projectName)/target — Rust Build Artifacts"
                        )
                        item.whyItExists = "Compiled binaries, incremental compiler caches, and intermediate build objects for \(projectName) (\(calc.fileCount) files)."
                        item.removalConsequence = "Project will recompile cleanly from source on next `cargo build`."
                        item.recoveryInstruction = "Rebuild with: cargo build (or run `cargo clean`)"

                        discovered.append(item)
                        onProgress?("Found Rust target: \(projectName) (\(ByteCountFormatter.string(fromByteCount: calc.allocatedBytes, countStyle: .file)))")
                        continue
                    }
                }

                // 4. Check for Swift Package Manager .build directories
                if scanSwift && dirName == ".build" {
                    let parentURL = fileURL.deletingLastPathComponent()
                    let packagePath = parentURL.appendingPathComponent("Package.swift").path
                    if fileManager.fileExists(atPath: packagePath) {
                        enumerator.skipDescendants() // Crucial: never crawl inside .build!

                        let path = fileURL.path
                        let projectName = parentURL.lastPathComponent
                        let calc = FileScanner.calculateDirectorySize(at: path)
                        guard calc.allocatedBytes > 0 else { continue }

                        var item = StorageItem(
                            path: path,
                            logicalSize: calc.allocatedBytes,
                            allocatedSize: calc.allocatedBytes,
                            category: .xcode,
                            risk: .low,
                            recoverability: .rebuildable,
                            whatIsThis: "\(projectName)/.build — SwiftPM Build Products"
                        )
                        item.whyItExists = "Swift Package Manager build binaries, modulemaps, and checkouts for \(projectName) (\(calc.fileCount) files)."
                        item.removalConsequence = "Project will recompile cleanly on next `swift build`."
                        item.recoveryInstruction = "Rebuild with: swift build"

                        discovered.append(item)
                        onProgress?("Found SwiftPM .build: \(projectName) (\(ByteCountFormatter.string(fromByteCount: calc.allocatedBytes, countStyle: .file)))")
                        continue
                    } else {
                        enumerator.skipDescendants()
                        continue
                    }
                }
            }
        }

        return discovered
    }
}
