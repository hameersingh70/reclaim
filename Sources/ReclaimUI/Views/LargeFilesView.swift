// LargeFilesView.swift
// ReclaimUI/Views
//
// Market-leading Large & Old Files inspector with size thresholding,
// file kind classifications (Archives, Media, Documents, Developer Artifacts),
// age filters (> 1 mo, > 6 mo, > 1 yr), and multi-select batch Trash operations.

import SwiftUI
import AppKit
import Reclaim

public struct LargeFilesView: View {
    @ObservedObject public var appState: AppState
    public let theme: any Theme
    public let onDeleteItem: (StorageItem) -> Void

    @State private var sizeFilterMB: Int64 = 100 // 100 MB default
    @State private var kindFilter: FileKindFilter = .all
    @State private var ageFilter: FileAgeFilter = .any
    @State private var searchQuery: String = ""

    public init(appState: AppState, theme: any Theme, onDeleteItem: @escaping (StorageItem) -> Void) {
        self.appState = appState
        self.theme = theme
        self.onDeleteItem = onDeleteItem
    }

    private var filteredFiles: [StorageItem] {
        let thresholdBytes = sizeFilterMB * 1_048_576
        return appState.storageItems
            .filter { item in
                guard item.allocatedSize >= thresholdBytes else { return false }
                guard kindFilter.matches(path: item.path) else { return false }
                guard ageFilter.matches(path: item.path) else { return false }
                if !searchQuery.isEmpty {
                    guard item.path.localizedCaseInsensitiveContains(searchQuery) else { return false }
                }
                return true
            }
            .sorted { $0.allocatedSize > $1.allocatedSize }
    }

    private var totalFilteredBytes: Int64 {
        filteredFiles.reduce(0) { $0 + $1.allocatedSize }
    }

    private var selectedFilteredBytes: Int64 {
        filteredFiles.filter { appState.isSelected($0.id) }.reduce(0) { $0 + $1.allocatedSize }
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header Bar (Neo-Brutalist Card)
            headerCard

            // Filters & Actions Toolbar
            filterToolbar

            // Files List or Empty State
            if filteredFiles.isEmpty {
                emptyState
            } else {
                itemsList
            }
        }
        .background(theme.windowBackground)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "scalemass.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 44, height: 44)
                .background(Color(red: 1.00, green: 0.40, blue: 0.42)) // Coral
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 2))
                .shadow(color: .black, radius: 0, x: 2, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text("Large & Old Files")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                Text("Surface heavyweight archives, stale disk images, and massive media files.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.65))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(ByteCountFormatter.string(fromByteCount: totalFilteredBytes, countStyle: .file))
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                    .foregroundColor(.black)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))

                Text("\(filteredFiles.count) matching items")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.6))
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
        .shadow(color: .black, radius: 0, x: 3, y: 3)
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Filter Toolbar

    private var filterToolbar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // Size threshold
                Picker("Size", selection: $sizeFilterMB) {
                    Text("> 50 MB").tag(Int64(50))
                    Text("> 100 MB").tag(Int64(100))
                    Text("> 500 MB").tag(Int64(500))
                    Text("> 1 GB").tag(Int64(1024))
                    Text("> 5 GB").tag(Int64(5120))
                }
                .frame(width: 120)

                // Kind Filter
                Picker("Kind", selection: $kindFilter) {
                    ForEach(FileKindFilter.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .frame(width: 160)

                // Age Filter
                Picker("Age", selection: $ageFilter) {
                    ForEach(FileAgeFilter.allCases) { age in
                        Text(age.rawValue).tag(age)
                    }
                }
                .frame(width: 120)

                // Search Box
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.black.opacity(0.6))
                    TextField("Filter path...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.2))

                Spacer()

                // Batch Selection Actions
                Button("Select All") {
                    let ids = Set(filteredFiles.map(\.id))
                    appState.selectedItemIDs.formUnion(ids)
                }
                .font(.system(size: 10, weight: .black, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                .buttonStyle(.plain)

                Button("Deselect") {
                    let ids = Set(filteredFiles.map(\.id))
                    appState.selectedItemIDs.subtract(ids)
                }
                .font(.system(size: 10, weight: .black, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                .buttonStyle(.plain)

                // Batch Trash Button
                Button {
                    let selected = filteredFiles.filter { appState.isSelected($0.id) }
                    for item in selected {
                        onDeleteItem(item)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 9))
                        Text("Delete Selected (\(ByteCountFormatter.string(fromByteCount: selectedFilteredBytes, countStyle: .file)))")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(selectedFilteredBytes > 0 ? Color(red: 1.00, green: 0.40, blue: 0.42) : Color.black.opacity(0.08))
                    .foregroundColor(selectedFilteredBytes > 0 ? .black : Color.black.opacity(0.4))
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                }
                .buttonStyle(.plain)
                .disabled(selectedFilteredBytes == 0)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color(red: 1.00, green: 0.72, blue: 0.18))
                    .frame(width: 64, height: 64)
                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
                    .shadow(color: .black, radius: 0, x: 3, y: 3)

                Image(systemName: "scalemass.fill")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.black)
            }

            Text("No files matching criteria found")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.black)
            Text("Try relaxing filters, reducing the minimum size, or running a Smart Scan.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color.black.opacity(0.65))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
        .shadow(color: .black, radius: 0, x: 3, y: 3)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Items List

    private var itemsList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(filteredFiles, id: \.id) { item in
                    HStack(spacing: 12) {
                        // Checkbox
                        Button {
                            appState.toggleSelection(for: item.id)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(appState.isSelected(item.id) ? Color.black : Color.white)
                                    .frame(width: 18, height: 18)
                                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black, lineWidth: 1.5))

                                if appState.isSelected(item.id) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        // File Icon
                        Image(systemName: iconForFile(path: item.path))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 24, height: 24)
                            .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(URL(fileURLWithPath: item.path).lastPathComponent)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.black)

                            Text(item.path)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color.black.opacity(0.6))
                                .lineLimit(1)
                        }

                        Spacer()

                        RiskBadge(risk: item.risk, theme: theme)

                        Text(item.formattedAllocatedSize)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(minWidth: 70, alignment: .trailing)

                        // Open Folder Button
                        Button {
                            var isDir: ObjCBool = false
                            let targetURL: URL
                            if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                                targetURL = URL(fileURLWithPath: item.path)
                            } else {
                                targetURL = URL(fileURLWithPath: item.path).deletingLastPathComponent()
                            }
                            NSWorkspace.shared.open(targetURL)
                        } label: {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.black)
                                .font(.system(size: 11))
                                .frame(width: 24, height: 24)
                                .background(Color.white)
                                .cornerRadius(5)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                                .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                        }
                        .buttonStyle(.plain)
                        .help("Open Folder in Finder")

                        // Direct Delete Button
                        Button {
                            onDeleteItem(item)
                        } label: {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.black)
                                .font(.system(size: 11))
                                .frame(width: 24, height: 24)
                                .background(Color(red: 1.00, green: 0.40, blue: 0.42))
                                .cornerRadius(5)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                                .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                        }
                        .buttonStyle(.plain)
                        .help("Delete this file immediately to Trash")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
                    .shadow(color: .black, radius: 0, x: 2, y: 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func iconForFile(path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        if ["dmg", "iso", "zip", "tar", "gz", "pkg"].contains(ext) { return "doc.zipper" }
        if ["mov", "mp4", "mkv", "avi"].contains(ext) { return "film" }
        if ["mp3", "wav", "flac"].contains(ext) { return "music.note" }
        if ["pdf", "docx", "pages"].contains(ext) { return "doc.text.fill" }
        return "doc.fill"
    }
}
