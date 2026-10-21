// FileKindFilter.swift
// Reclaim/Core/Storage
//
// File kind classification and age filter criteria for large file inspection.

import Foundation

public enum FileKindFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All Kinds"
    case archives = "Archives & Disk Images"
    case media = "Videos & Media"
    case audio = "Audio"
    case documents = "Documents"
    case developer = "Developer Artifacts"

    public var id: String { rawValue }

    public func matches(path: String) -> Bool {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch self {
        case .all:
            return true
        case .archives:
            return ["dmg", "iso", "zip", "tar", "gz", "tgz", "bz2", "7z", "pkg", "xip", "rar"].contains(ext)
        case .media:
            return ["mov", "mp4", "mkv", "avi", "m4v", "webm", "flv", "wmv"].contains(ext)
        case .audio:
            return ["mp3", "wav", "flac", "aac", "m4a", "ogg", "aiff"].contains(ext)
        case .documents:
            return ["pdf", "docx", "doc", "xlsx", "xls", "pptx", "ppt", "csv", "epub", "pages", "numbers", "key"].contains(ext)
        case .developer:
            return ["app", "dylib", "o", "a", "framework", "bin", "whl", "tar", "gem"].contains(ext)
                || path.contains("DerivedData") || path.contains("node_modules")
        }
    }
}

public enum FileAgeFilter: String, CaseIterable, Identifiable, Sendable {
    case any = "Any Age"
    case oneMonth = "> 1 Month"
    case sixMonths = "> 6 Months"
    case oneYear = "> 1 Year"

    public var id: String { rawValue }

    public var minAgeDays: Int {
        switch self {
        case .any: return 0
        case .oneMonth: return 30
        case .sixMonths: return 180
        case .oneYear: return 365
        }
    }

    public func matches(path: String) -> Bool {
        guard minAgeDays > 0 else { return true }
        var st = stat()
        guard lstat(path, &st) == 0 else { return true }
        let modTime = Date(timeIntervalSince1970: Double(st.st_mtimespec.tv_sec))
        let cutoff = Date().addingTimeInterval(-Double(minAgeDays * 86400))
        return modTime < cutoff
    }
}
