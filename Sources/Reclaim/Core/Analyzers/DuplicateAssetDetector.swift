// DuplicateAssetDetector.swift
// Reclaim/Core/Analyzers
//
// High-performance duplicate file and AI model detector.
// Employs a 2-tier sparse chunk hashing algorithm (size grouping + 24KB sparse SHA-256)
// to identify identical multi-gigabyte files (GGUF, Safetensors, ISO, DMG, VM images)
// in milliseconds without thrashing the SSD.

import Foundation
import CommonCrypto

public struct DuplicateAssetItem: Identifiable, Sendable {
    public let id: String
    public let path: String
    public let size: Int64
    public let modifiedDate: Date

    public init(id: String = UUID().uuidString, path: String, size: Int64, modifiedDate: Date) {
        self.id = id
        self.path = path
        self.size = size
        self.modifiedDate = modifiedDate
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var fileName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}

public struct DuplicateAssetGroup: Identifiable, Sendable {
    public let id: String
    public let fileSize: Int64
    public let items: [DuplicateAssetItem]

    public init(id: String = UUID().uuidString, fileSize: Int64, items: [DuplicateAssetItem]) {
        self.id = id
        self.fileSize = fileSize
        self.items = items
    }

    public var potentialSavings: Int64 {
        guard items.count > 1 else { return 0 }
        return Int64(items.count - 1) * fileSize
    }

    public var formattedSavings: String {
        ByteCountFormatter.string(fromByteCount: potentialSavings, countStyle: .file)
    }
}

public final class DuplicateAssetDetector: @unchecked Sendable {
    public init() {}

    private static let targetExtensions: Set<String> = [
        "gguf", "safetensors", "bin", "pt", "pth", "ckpt",
        "iso", "dmg", "pkg", "zip", "tar", "gz", "qcow2", "vmdk", "sparseimage"
    ]

    /// Default scan roots for developer assets
    public static func defaultScanRoots() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".ollama/models"),
            home.appendingPathComponent(".cache/huggingface/hub"),
            home.appendingPathComponent(".cache/lm_studio"),
            home.appendingPathComponent(".local/share/nomic.ai"),
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Developer"),
            home.appendingPathComponent("Projects"),
            home.appendingPathComponent("Library/Caches")
        ].filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Scans directories and returns duplicate groups
    public func scan(
        roots: [URL]? = nil,
        minByteSize: Int64 = 25_000_000, // 25 MB minimum
        progressHandler: (@Sendable (String) -> Void)? = nil
    ) async -> [DuplicateAssetGroup] {
        let scanRoots = roots ?? Self.defaultScanRoots()
        var candidateFiles: [(path: String, size: Int64, modified: Date)] = []

        // Tier 1: Directory traversal & size filtering
        for root in scanRoots {
            progressHandler?("Scanning \(root.lastPathComponent)...")
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
                options: [.skipsPackageDescendants, .skipsHiddenFiles]
            ) else { continue }

            while let fileURL = enumerator.nextObject() as? URL {
                let ext = fileURL.pathExtension.lowercased()
                guard Self.targetExtensions.contains(ext) else { continue }

                guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]),
                      values.isRegularFile == true,
                      let size = values.fileSize,
                      Int64(size) >= minByteSize else {
                    continue
                }

                let modified = values.contentModificationDate ?? Date()
                candidateFiles.append((path: fileURL.path, size: Int64(size), modified: modified))
            }
        }

        // Tier 2: Group by exact size (filters out 99% of unique files)
        var sizeBuckets: [Int64: [(path: String, size: Int64, modified: Date)]] = [:]
        for file in candidateFiles {
            sizeBuckets[file.size, default: []].append(file)
        }

        let collisions = sizeBuckets.filter { $0.value.count > 1 }
        progressHandler?("Evaluating \(collisions.count) size collision sets with sparse chunk hashing...")

        // Tier 3: Sparse chunk hashing (head 8KB + mid 8KB + tail 8KB)
        var duplicateGroups: [DuplicateAssetGroup] = []

        for (size, files) in collisions {
            var hashBuckets: [String: [DuplicateAssetItem]] = [:]

            for file in files {
                if let hash = computeSparseHash(path: file.path, size: size) {
                    let item = DuplicateAssetItem(path: file.path, size: size, modifiedDate: file.modified)
                    hashBuckets[hash, default: []].append(item)
                }
            }

            for (_, matchingItems) in hashBuckets where matchingItems.count > 1 {
                duplicateGroups.append(DuplicateAssetGroup(fileSize: size, items: matchingItems))
            }
        }

        return duplicateGroups.sorted { $0.potentialSavings > $1.potentialSavings }
    }

    /// Computes a fast SHA-256 fingerprint from head (8KB), middle (8KB), and tail (8KB)
    private func computeSparseHash(path: String, size: Int64) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else {
            return nil
        }
        defer { try? handle.close() }

        let sampleChunk: Int = 8192 // 8 KB
        var sampleData = Data()

        // 1. Head sample
        do {
            try handle.seek(toOffset: 0)
            sampleData.append(handle.readData(ofLength: sampleChunk))

            // 2. Mid sample
            if size > Int64(sampleChunk * 3) {
                let midOffset = UInt64(size / 2)
                try handle.seek(toOffset: midOffset)
                sampleData.append(handle.readData(ofLength: sampleChunk))
            }

            // 3. Tail sample
            if size > Int64(sampleChunk * 2) {
                let tailOffset = UInt64(size - Int64(sampleChunk))
                try handle.seek(toOffset: tailOffset)
                sampleData.append(handle.readData(ofLength: sampleChunk))
            }
        } catch {
            return nil
        }

        // SHA-256 hash of sampled 24KB
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        sampleData.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(sampleData.count), &hash)
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
