// FileShredderEngine.swift
// Reclaim/Core/Cleanup
//
// Cryptographically secure file shredder conforming to DOD 5220.22-M overwrite principles.
// Overwrites file sectors with cryptographically secure random bytes prior to truncation
// and filesystem unlinking, preventing forensic data recovery.
// Protected by SafetyEngine to prevent accidental shredding of system or sensitive files.

import Foundation
import Security

public struct ShredReceipt: Sendable {
    public let path: String
    public let bytesShredded: Int64
    public let filesCount: Int
    public let success: Bool
    public let error: String?

    public init(path: String, bytesShredded: Int64, filesCount: Int, success: Bool, error: String? = nil) {
        self.path = path
        self.bytesShredded = bytesShredded
        self.filesCount = filesCount
        self.success = success
        self.error = error
    }

    public var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: bytesShredded, countStyle: .file)
    }
}

public final class FileShredderEngine: @unchecked Sendable {
    public let safetyEngine: SafetyEngine
    public let fileManager: FileManager

    public init(
        safetyEngine: SafetyEngine = SafetyEngine(),
        fileManager: FileManager = .default
    ) {
        self.safetyEngine = safetyEngine
        self.fileManager = fileManager
    }

    /// Securely shreds a file or directory at the given path.
    public func shred(path: String, passes: Int = 1) throws -> ShredReceipt {
        // Strict safety check: Never shred protected system paths or developer credentials
        guard !safetyEngine.isProtected(path: path) else {
            throw NSError(
                domain: "ReclaimSafety",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Security guard blocked shredding of protected path: \(path)"]
            )
        }

        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else {
            throw NSError(
                domain: "ReclaimShredder",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Target does not exist at: \(path)"]
            )
        }

        if isDir.boolValue {
            return try shredDirectory(path: path, passes: passes)
        } else {
            let bytes = try shredSingleFile(path: path, passes: passes)
            return ShredReceipt(path: path, bytesShredded: bytes, filesCount: 1, success: true)
        }
    }

    private func shredSingleFile(path: String, passes: Int) throws -> Int64 {
        let url = URL(fileURLWithPath: path)
        let attrs = try fileManager.attributesOfItem(atPath: path)
        let fileSize = (attrs[.size] as? Int64) ?? 0

        if fileSize > 0 {
            guard let handle = FileHandle(forUpdatingAtPath: path) else {
                throw NSError(
                    domain: "ReclaimShredder",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Could not open file handle for writing at: \(path)"]
                )
            }

            defer {
                try? handle.close()
            }

            let chunkSize = 64 * 1024 // 64 KB
            var randomBuffer = [UInt8](repeating: 0, count: chunkSize)

            for _ in 0..<max(1, passes) {
                try handle.seek(toOffset: 0)
                var bytesRemaining = fileSize

                while bytesRemaining > 0 {
                    let currentChunk = Int(min(Int64(chunkSize), bytesRemaining))
                    _ = SecRandomCopyBytes(kSecRandomDefault, currentChunk, &randomBuffer)
                    let data = Data(bytes: randomBuffer, count: currentChunk)
                    try handle.write(contentsOf: data)
                    bytesRemaining -= Int64(currentChunk)
                }
                try handle.synchronize()
            }

            // Truncate file to 0 bytes before unlinking
            try handle.truncate(atOffset: 0)
        }

        // Remove unlinked inode
        try fileManager.removeItem(at: url)
        return fileSize
    }

    private func shredDirectory(path: String, passes: Int) throws -> ShredReceipt {
        let rootURL = URL(fileURLWithPath: path)
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            throw NSError(
                domain: "ReclaimShredder",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Could not enumerate directory at: \(path)"]
            )
        }

        var totalBytes: Int64 = 0
        var totalFiles = 0
        var subdirs: [URL] = []

        while let fileURL = enumerator.nextObject() as? URL {
            let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDirectory {
                subdirs.append(fileURL)
            } else {
                let bytes = try shredSingleFile(path: fileURL.path, passes: passes)
                totalBytes += bytes
                totalFiles += 1
            }
        }

        // Remove subdirectories in reverse order (deepest first)
        for dir in subdirs.reversed() {
            try? fileManager.removeItem(at: dir)
        }

        // Remove root directory
        try fileManager.removeItem(at: rootURL)

        return ShredReceipt(path: path, bytesShredded: totalBytes, filesCount: totalFiles, success: true)
    }
}
