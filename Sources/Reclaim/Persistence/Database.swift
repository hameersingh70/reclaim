// Database.swift
// Persistence/
//
// Native SQLite3 persistence layer without external dependencies (PRD §26).
// Stores scan metadata, cleanup receipts, and aggregate storage history.

import Foundation
import SQLite3

public enum DatabaseError: Error {
    case connectionFailed
    case queryFailed(String)
}

public final class Database: @unchecked Sendable {
    private var db: OpaquePointer?

    public init(path: String = ":memory:") throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            throw DatabaseError.connectionFailed
        }
        try setupSchema()
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    private func setupSchema() throws {
        let schema = """
        CREATE TABLE IF NOT EXISTS items (
            id TEXT PRIMARY KEY,
            path TEXT NOT NULL,
            logicalSize INTEGER NOT NULL,
            allocatedSize INTEGER NOT NULL,
            reclaimableSize INTEGER NOT NULL,
            category TEXT NOT NULL,
            risk TEXT NOT NULL,
            recoverability TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS receipts (
            id TEXT PRIMARY KEY,
            timestamp REAL NOT NULL,
            beforeAvailable INTEGER NOT NULL,
            afterAvailable INTEGER NOT NULL,
            actualRecovered INTEGER NOT NULL,
            actionsJson TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp REAL NOT NULL,
            totalUsed INTEGER NOT NULL,
            available INTEGER NOT NULL,
            reclaimable INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS directory_cache (
            path TEXT PRIMARY KEY,
            mtime REAL NOT NULL,
            allocatedBytes INTEGER NOT NULL DEFAULT 0,
            fileCount INTEGER NOT NULL DEFAULT 0,
            lastScanned REAL NOT NULL
        );
        """
        try execute(schema)
    }

    // MARK: - Incremental Indexing: mtime Cache

    /// Returns the cached mtime for a directory path, or nil if not yet indexed.
    public func cachedMtime(for path: String) -> Double? {
        let sql = "SELECT mtime FROM directory_cache WHERE path = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, path, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return sqlite3_column_double(stmt, 0)
    }

    /// Returns cached directory stats (allocatedBytes, fileCount, mtime) if unchanged, or nil if changed/missing.
    public func cachedDirectoryStats(for path: String) -> (allocatedBytes: Int64, fileCount: Int)? {
        guard let cached = cachedMtime(for: path) else { return nil }
        var st = stat()
        guard lstat(path, &st) == 0 else { return nil }
        let diskMtime = Double(st.st_mtimespec.tv_sec) + Double(st.st_mtimespec.tv_nsec) / 1_000_000_000
        guard abs(diskMtime - cached) < 0.001 else { return nil }

        let sql = "SELECT allocatedBytes, fileCount FROM directory_cache WHERE path = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, path, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        let bytes = sqlite3_column_int64(stmt, 0)
        let count = Int(sqlite3_column_int(stmt, 1))
        return (bytes, count)
    }

    /// Updates (or inserts) the mtime entry for a directory path.
    public func updateMtime(for path: String, mtime: Double) {
        updateDirectoryCache(for: path, mtime: mtime, allocatedBytes: 0, fileCount: 0)
    }

    /// Updates (or inserts) full directory cache data including size and count.
    public func updateDirectoryCache(for path: String, mtime: Double, allocatedBytes: Int64, fileCount: Int) {
        let sql = """
        INSERT OR REPLACE INTO directory_cache (path, mtime, allocatedBytes, fileCount, lastScanned)
        VALUES (?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, path, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 2, mtime)
        sqlite3_bind_int64(stmt, 3, allocatedBytes)
        sqlite3_bind_int(stmt, 4, Int32(fileCount))
        sqlite3_bind_double(stmt, 5, Date().timeIntervalSince1970)
        _ = sqlite3_step(stmt)
    }

    /// Returns true if the directory at `path` is unchanged since last scan (mtime matches cache).
    public func isDirectoryUnchanged(path: String) -> Bool {
        guard let cached = cachedMtime(for: path) else { return false }
        var st = stat()
        guard lstat(path, &st) == 0 else { return false }
        let diskMtime = Double(st.st_mtimespec.tv_sec) + Double(st.st_mtimespec.tv_nsec) / 1_000_000_000
        return abs(diskMtime - cached) < 0.001
    }

    /// Invalidates (deletes) cache entries for a path, its parents, or its child subdirectories.
    public func invalidateCache(for path: String) {
        let sql = """
        DELETE FROM directory_cache 
        WHERE path = ? 
           OR ? LIKE (path || '/%') 
           OR path LIKE (? || '/%');
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, path, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, path, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, path, -1, SQLITE_TRANSIENT)
        _ = sqlite3_step(stmt)
    }

    /// Clears all directory cache entries completely.
    public func clearDirectoryCache() {
        _ = try? execute("DELETE FROM directory_cache;")
    }

    public func execute(_ sql: String) throws {
        var errMsg: UnsafeMutablePointer<Int8>? = nil
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg != nil ? String(cString: errMsg!) : "Unknown SQLite error"
            sqlite3_free(errMsg)
            throw DatabaseError.queryFailed(msg)
        }
    }

    public func save(item: StorageItem) throws {
        let sql = """
        INSERT OR REPLACE INTO items (id, path, logicalSize, allocatedSize, reclaimableSize, category, risk, recoverability)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed("Prepare failed for item insert")
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, item.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, item.path, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 3, item.logicalSize)
        sqlite3_bind_int64(stmt, 4, item.allocatedSize)
        sqlite3_bind_int64(stmt, 5, item.estimatedReclaimableSize)
        sqlite3_bind_text(stmt, 6, item.category.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 7, item.risk.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 8, item.recoverability.rawValue, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.queryFailed("Step failed for item insert")
        }
    }

    public func save(receipt: CleanupReceipt) throws {
        let sql = """
        INSERT INTO receipts (id, timestamp, beforeAvailable, afterAvailable, actualRecovered, actionsJson)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed("Prepare failed for receipt insert")
        }
        defer { sqlite3_finalize(stmt) }

        let jsonData = (try? JSONEncoder().encode(receipt.actions)) ?? Data()
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

        sqlite3_bind_text(stmt, 1, receipt.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 2, receipt.timestamp.timeIntervalSince1970)
        sqlite3_bind_int64(stmt, 3, receipt.beforeAvailableBytes)
        sqlite3_bind_int64(stmt, 4, receipt.afterAvailableBytes)
        sqlite3_bind_int64(stmt, 5, receipt.actualRecoveredBytes)
        sqlite3_bind_text(stmt, 6, jsonString, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.queryFailed("Step failed for receipt insert")
        }
    }

    public func recordHistory(totalUsed: Int64, available: Int64, reclaimable: Int64) throws {
        let sql = """
        INSERT INTO history (timestamp, totalUsed, available, reclaimable)
        VALUES (?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed("Prepare failed for history insert")
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
        sqlite3_bind_int64(stmt, 2, totalUsed)
        sqlite3_bind_int64(stmt, 3, available)
        sqlite3_bind_int64(stmt, 4, reclaimable)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.queryFailed("Step failed for history insert")
        }
    }

    public func queryInt(_ sql: String) throws -> Int {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw DatabaseError.queryFailed("Prepare failed")
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }

    /// Fetches persisted cleanup receipts ordered by timestamp descending.
    public func fetchReceipts(limit: Int = 50) -> [CleanupReceipt] {
        let sql = "SELECT id, timestamp, beforeAvailable, afterAvailable, actualRecovered, actionsJson FROM receipts ORDER BY timestamp DESC LIMIT ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(limit))

        var receipts: [CleanupReceipt] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idStr = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
                  let id = UUID(uuidString: idStr) else { continue }
            let timeVal = sqlite3_column_double(stmt, 1)
            let before = sqlite3_column_int64(stmt, 2)
            let after = sqlite3_column_int64(stmt, 3)
            let recovered = sqlite3_column_int64(stmt, 4)
            let actionsJson = sqlite3_column_text(stmt, 5).map({ String(cString: $0) }) ?? "[]"

            let actions = (try? JSONDecoder().decode([CleanupActionSummary].self, from: Data(actionsJson.utf8))) ?? []
            let receipt = CleanupReceipt(
                id: id,
                timestamp: Date(timeIntervalSince1970: timeVal),
                beforeAvailableBytes: before,
                afterAvailableBytes: after,
                actualRecoveredBytes: recovered,
                actions: actions
            )
            receipts.append(receipt)
        }
        return receipts
    }
}

// Swift helper for SQLITE_TRANSIENT destructor
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
