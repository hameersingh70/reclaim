// FileScanner.swift
// Core/Scanner
//
// High-performance POSIX fts(3) file system scanner for macOS APFS.
// Avoids Foundation / NSURL allocation overhead, eliminates redundant syscalls,
// guarantees O(1) symlink loop immunity, and uses fast integer inode deduplication.

import Foundation
import Darwin

public final class FileScanner: @unchecked Sendable {
    public let rootURL: URL
    public let skipHidden: Bool
    public let maxDepth: Int?

    public init(rootURL: URL, skipHidden: Bool = false, maxDepth: Int? = nil) {
        self.rootURL = rootURL
        self.skipHidden = skipHidden
        self.maxDepth = maxDepth
    }

    /// Fast APFS directory size calculator without allocating high-level objects.
    public static func calculateDirectorySize(at path: String) -> (allocatedBytes: Int64, fileCount: Int) {
        var totalAllocated: Int64 = 0
        var totalFiles = 0

        path.withCString { cPath in
            var paths: [UnsafeMutablePointer<CChar>?] = [strdup(cPath), nil]
            defer { free(paths[0]) }

            let ftsOptions = FTS_PHYSICAL | FTS_NOCHDIR
            guard let tree = fts_open(&paths, ftsOptions, nil) else { return }
            defer { fts_close(tree) }

            var primaryDevice: UInt64 = 0
            var primaryInodes = Set<UInt64>(minimumCapacity: 16384)

            while let node = fts_read(tree) {
                let info = Int32(node.pointee.fts_info)
                if info == FTS_DNR || info == FTS_ERR || info == FTS_NS || info == FTS_D || info == FTS_DP {
                    continue
                }

                guard let statPtr = node.pointee.fts_statp else { continue }
                let statInfo = statPtr.pointee
                let dev = UInt64(statInfo.st_dev)
                let ino = UInt64(statInfo.st_ino)

                if primaryDevice == 0 { primaryDevice = dev }
                if dev == primaryDevice {
                    if primaryInodes.contains(ino) { continue }
                    primaryInodes.insert(ino)
                }

                totalFiles += 1
                totalAllocated += Int64(statInfo.st_blocks) * 512
            }
        }

        return (totalAllocated, totalFiles)
    }

    public func scan() -> AsyncStream<StorageItem> {
        return AsyncStream { continuation in
            let task = Task {
                let pathString = rootURL.path
                pathString.withCString { cPath in
                    var paths: [UnsafeMutablePointer<CChar>?] = [strdup(cPath), nil]
                    defer { free(paths[0]) }

                    // FTS_PHYSICAL: Do not follow symlinks (prevents recursive loops at kernel level)
                    // FTS_NOCHDIR: Do not change process working directory during scan (thread-safe)
                    let ftsOptions = FTS_PHYSICAL | FTS_NOCHDIR
                    guard let tree = fts_open(&paths, ftsOptions, nil) else {
                        continuation.finish()
                        return
                    }
                    defer { fts_close(tree) }

                    // Fast integer inode tracking (O(1) lookup without multi-field struct hashing)
                    var primaryDevice: UInt64 = 0
                    var primaryInodes = Set<UInt64>(minimumCapacity: 32768)
                    var crossDeviceInodes: [UInt64: Set<UInt64>] = [:]

                    while let node = fts_read(tree) {
                        if Task.isCancelled { break }

                        let info = Int32(node.pointee.fts_info)

                        // Skip error or unreadable nodes gracefully (permission tolerance)
                        if info == FTS_DNR || info == FTS_ERR || info == FTS_NS {
                            continue
                        }

                        // Under FTS_PHYSICAL, symlinks are returned as FTS_SL/FTS_SLNONE without descending
                        let isSymlink = (info == FTS_SL || info == FTS_SLNONE)

                        // Directory pre-order: FTS_D
                        if info == FTS_D {
                            if let maxDepth = maxDepth, node.pointee.fts_level >= maxDepth {
                                fts_set(tree, node, FTS_SKIP)
                                continue
                            }

                            if skipHidden && node.pointee.fts_level > 0 {
                                let path = String(cString: node.pointee.fts_path)
                                if let lastSlash = path.lastIndex(of: "/") {
                                    let name = path[path.index(after: lastSlash)...]
                                    if name.hasPrefix(".") {
                                        fts_set(tree, node, FTS_SKIP)
                                        continue
                                    }
                                }
                            }
                            continue
                        }

                        // Directory post-order: FTS_DP
                        if info == FTS_DP {
                            continue
                        }

                        // Regular file (FTS_F), symlink (FTS_SL), or special file
                        guard let statPtr = node.pointee.fts_statp else { continue }
                        let statInfo = statPtr.pointee

                        let dev = UInt64(statInfo.st_dev)
                        let ino = UInt64(statInfo.st_ino)

                        // Hard-link / inode deduplication:
                        if primaryDevice == 0 {
                            primaryDevice = dev
                        }

                        var isDuplicateInode = false
                        if dev == primaryDevice {
                            if primaryInodes.contains(ino) {
                                isDuplicateInode = true
                            } else {
                                primaryInodes.insert(ino)
                            }
                        } else {
                            if crossDeviceInodes[dev]?.contains(ino) == true {
                                isDuplicateInode = true
                            } else {
                                crossDeviceInodes[dev, default: []].insert(ino)
                            }
                        }

                        if isDuplicateInode {
                            continue
                        }

                        let itemPath = String(cString: node.pointee.fts_path)
                        let logicalSize = Int64(statInfo.st_size)
                        // On macOS / APFS, st_blocks is 512-byte units allocating actual disk blocks
                        let allocatedSize = Int64(statInfo.st_blocks) * 512

                        let item = StorageItem(
                            path: itemPath,
                            logicalSize: max(0, logicalSize),
                            allocatedSize: max(0, allocatedSize),
                            isSymlink: isSymlink,
                            isHardLink: statInfo.st_nlink > 1,
                            inodeKey: InodeKey(device: dev, inode: ino)
                        )

                        continuation.yield(item)
                    }

                    continuation.finish()
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
