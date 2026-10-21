// ExplorerView.swift
// ReclaimUI/Views
//
// Interactive storage explorer allowing developers to search, filter by ecosystem/risk,
// sort by size, and inspect detailed domain evidence per PRD §16 and §47.
// Completely free of rigid HSplitView: full width by default, side inspector on selection.

import SwiftUI
import AppKit
import Reclaim

public struct ExplorerView: View {
    @ObservedObject public var appState: AppState
    public let theme: any Theme
    public var onDeleteItem: ((StorageItem) -> Void)? = nil

    public enum ExplorerViewMode: Sendable {
        case list
        case spaceMap
    }

    @State private var viewMode: ExplorerViewMode = .list
    @State private var selectedCategory: StorageCategory? = nil
    @State private var selectedRisk: StorageRiskLevel? = nil
    @State private var selectedItem: StorageItem? = nil
    @State private var searchQuery: String = ""
    @State private var sortByReclaimable: Bool = true

    public init(
        appState: AppState,
        theme: any Theme,
        onDeleteItem: ((StorageItem) -> Void)? = nil
    ) {
        self.appState = appState
        self.theme = theme
        self.onDeleteItem = onDeleteItem
    }

    private var filteredItems: [StorageItem] {
        var items = appState.storageItems

        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }

        if let risk = selectedRisk {
            items = items.filter { $0.risk == risk }
        }

        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            items = items.filter { $0.path.lowercased().contains(query) }
        }

        if sortByReclaimable {
            items.sort { $0.estimatedReclaimableSize > $1.estimatedReclaimableSize }
        } else {
            items.sort { $0.allocatedSize > $1.allocatedSize }
        }

        return items
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Main Explorer List (expands to full width when no item is inspected)
            VStack(spacing: 0) {
                topControlsHeader

                if filteredItems.isEmpty {
                    emptyStateView
                } else if viewMode == .spaceMap {
                    spaceMapView
                } else {
                    itemsScrollView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.windowBackground)

            // Side Inspector Panel (slides in when an item is selected)
            if let item = selectedItem {
                Rectangle()
                    .frame(width: 1.5)
                    .foregroundColor(.black)

                VStack(spacing: 0) {
                    // Inspector Header with Close [✕]
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                            Text("ITEM INTELLIGENCE")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1.2))

                        Spacer()

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedItem = nil
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(.black)
                                .frame(width: 24, height: 24)
                                .background(Color.white)
                                .cornerRadius(5)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                                .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                        }
                        .buttonStyle(.plain)
                        .help("Close Inspector")
                    }
                    .padding(12)
                    .background(Color.white)
                    .overlay(Rectangle().frame(height: 1.5).foregroundColor(.black), alignment: .bottom)

                    InspectorView(
                        item: item,
                        theme: theme,
                        onDeleteItem: {
                            onDeleteItem?(item)
                            withAnimation {
                                selectedItem = nil
                            }
                        },
                        onRevealInFinder: {
                            NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                        }
                    )
                }
                .frame(width: 340)
                .background(theme.windowBackground)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .onAppear {
            if CommandLine.arguments.contains("--inspect") && selectedItem == nil {
                selectedItem = filteredItems.first
            }
        }
        .onChange(of: appState.storageItems.count) { _ in
            if CommandLine.arguments.contains("--inspect") && selectedItem == nil {
                selectedItem = filteredItems.first
            }
        }
    }

    // MARK: - Top Controls Header

    private var topControlsHeader: some View {
        VStack(spacing: 10) {
            // Title & Match Count Row
            HStack {
                HStack(spacing: 8) {
                    Text("STORAGE EXPLORER")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.35, green: 0.75, blue: 1.0))
                        .foregroundColor(.black)
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1.2))

                    Text("\(filteredItems.count) items")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color.black.opacity(0.7))
                }

                Spacer()

                // View Mode selector (List vs Space Map)
                HStack(spacing: 4) {
                    Button(action: { viewMode = .list }) {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                            Text("LIST")
                        }
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(viewMode == .list ? Color(red: 0.35, green: 0.75, blue: 1.0) : Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewMode = .spaceMap }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.grid.2x2.fill")
                            Text("SPACE MAP")
                        }
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(viewMode == .spaceMap ? Color(red: 0.35, green: 0.75, blue: 1.0) : Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)
                }

                // Sort selector
                HStack(spacing: 6) {
                    Button(action: { sortByReclaimable = true }) {
                        Text("SORT: RECLAIMABLE")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(sortByReclaimable ? Color(red: 1.00, green: 0.72, blue: 0.18) : Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)

                    Button(action: { sortByReclaimable = false }) {
                        Text("SORT: ON DISK")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(!sortByReclaimable ? Color(red: 1.00, green: 0.72, blue: 0.18) : Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Search Bar & Filter Pickers
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.black)
                        .font(.system(size: 12, weight: .bold))

                    TextField("Filter by path, name, or tool...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium, design: .rounded))

                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.black.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white)
                .cornerRadius(7)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black, lineWidth: 1.5))
                .shadow(color: .black, radius: 0, x: 2, y: 2)

                // Category Picker
                Picker("", selection: $selectedCategory) {
                    Text("All Toolchains").tag(StorageCategory?.none)
                    Divider()
                    ForEach(StorageCategory.allCases, id: \.self) { cat in
                        Text(cat.displayName).tag(StorageCategory?.some(cat))
                    }
                }
                .frame(width: 150)

                // Risk Filter
                Picker("", selection: $selectedRisk) {
                    Text("All Risks").tag(StorageRiskLevel?.none)
                    Divider()
                    Text("Safe Only").tag(StorageRiskLevel?.some(.safe))
                    Text("Low Risk").tag(StorageRiskLevel?.some(.low))
                    Text("Medium Risk").tag(StorageRiskLevel?.some(.medium))
                    Text("High Risk").tag(StorageRiskLevel?.some(.high))
                }
                .frame(width: 120)
            }
        }
        .padding(14)
        .background(Color.white)
        .overlay(Rectangle().frame(height: 1.5).foregroundColor(.black), alignment: .bottom)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 38))
                .foregroundColor(Color.black.opacity(0.35))

            Text(appState.storageItems.isEmpty ? "No items scanned yet. Run a Smart Scan above." : "No matching items found.")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.65))

            if !searchQuery.isEmpty || selectedCategory != nil || selectedRisk != nil {
                Button("Clear All Filters") {
                    searchQuery = ""
                    selectedCategory = nil
                    selectedRisk = nil
                }
                .font(.system(size: 11, weight: .black, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.2))
                .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Space Map View (DaisyDisk / Space Lens style)

    private var spaceMapView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Top Storage Distribution Bar
                let totalBytes = max(1, filteredItems.reduce(0) { $0 + $1.allocatedSize })
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("STORAGE DISTRIBUTION MAP")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                        Spacer()
                        Text("Total: \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.black.opacity(0.7))
                    }

                    // Stacked Proportional Bar
                    GeometryReader { geo in
                        HStack(spacing: 1.5) {
                            ForEach(Array(filteredItems.prefix(12).enumerated()), id: \.element.id) { _, item in
                                let fraction = max(0.015, CGFloat(item.allocatedSize) / CGFloat(totalBytes))
                                let width = max(4, geo.size.width * fraction)
                                Rectangle()
                                    .fill(categoryColor(for: item.category))
                                    .frame(width: width, height: 16)
                                    .overlay(
                                        Rectangle()
                                            .stroke(selectedItem?.id == item.id ? Color.black : Color.clear, lineWidth: 1.5)
                                    )
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedItem = item
                                        }
                                    }
                            }
                        }
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1.5))
                    }
                    .frame(height: 16)
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
                .shadow(color: .black, radius: 0, x: 2, y: 2)

                // Visual Tiles Grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 10)], spacing: 10) {
                    ForEach(filteredItems, id: \.id) { item in
                        let isSelected = selectedItem?.id == item.id
                        let fraction = Double(item.allocatedSize) / Double(totalBytes)
                        let percentStr = String(format: "%.1f%%", fraction * 100)

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedItem = item
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: categoryIcon(for: item.category))
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(width: 22, height: 22)
                                        .background(categoryColor(for: item.category))
                                        .cornerRadius(4)
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1))

                                    Spacer()

                                    Text(percentStr)
                                        .font(.system(size: 10, weight: .black, design: .monospaced))
                                        .foregroundColor(Color.black.opacity(0.6))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(URL(fileURLWithPath: item.path).lastPathComponent)
                                        .font(.system(size: 12, weight: .black, design: .rounded))
                                        .foregroundColor(.black)
                                        .lineLimit(1)

                                    Text(ByteCountFormatter.string(fromByteCount: item.allocatedSize, countStyle: .file))
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color(red: 0.85, green: 0.35, blue: 0.05))
                                }

                                // Mini progress bar representing relative weight
                                GeometryReader { g in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.black.opacity(0.08))
                                            .frame(height: 4)
                                        Rectangle()
                                            .fill(categoryColor(for: item.category))
                                            .frame(width: max(3, g.size.width * CGFloat(min(1.0, fraction * 2.5))), height: 4)
                                    }
                                    .cornerRadius(2)
                                }
                                .frame(height: 4)
                            }
                            .padding(12)
                            .background(isSelected ? Color(red: 1.00, green: 0.95, blue: 0.80) : Color.white)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: isSelected ? 2 : 1.2))
                            .shadow(color: .black, radius: 0, x: isSelected ? 2.5 : 1.5, y: isSelected ? 2.5 : 1.5)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Items Scroll View

    private var itemsScrollView: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(filteredItems, id: \.id) { item in
                    let isSelected = selectedItem?.id == item.id

                    HStack(spacing: 10) {
                        // Category Icon
                        Image(systemName: categoryIcon(for: item.category))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 24, height: 24)
                            .background(categoryColor(for: item.category))
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))

                        // Path / File Name
                        VStack(alignment: .leading, spacing: 2) {
                            Text(URL(fileURLWithPath: item.path).lastPathComponent)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                                .lineLimit(1)

                            Text(item.path)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color.black.opacity(0.55))
                                .lineLimit(1)
                        }

                        Spacer()

                        // Risk Badge
                        RiskBadge(risk: item.risk, theme: theme)

                        // Size
                        Text(item.formattedAllocatedSize)
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(minWidth: 65, alignment: .trailing)

                        // Action: Reveal in Finder
                        Button(action: {
                            NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                        }) {
                            Image(systemName: "folder")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 24, height: 24)
                                .background(Color.white)
                                .cornerRadius(5)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                                .shadow(color: .black, radius: 0, x: 1, y: 1)
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")

                        // Action: Delete Item
                        if item.isEligibleForPlan {
                            Button(action: {
                                onDeleteItem?(item)
                                if selectedItem?.id == item.id {
                                    selectedItem = nil
                                }
                            }) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 24, height: 24)
                                    .background(Color(red: 1.00, green: 0.40, blue: 0.42))
                                    .cornerRadius(5)
                                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                                    .shadow(color: .black, radius: 0, x: 1, y: 1)
                            }
                            .buttonStyle(.plain)
                            .help("Move to Trash")
                        }

                        // Action: Inspect Button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if selectedItem?.id == item.id {
                                    selectedItem = nil
                                } else {
                                    selectedItem = item
                                }
                            }
                        }) {
                            Image(systemName: isSelected ? "info.circle.fill" : "info.circle")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 24, height: 24)
                                .background(isSelected ? Color(red: 1.00, green: 0.72, blue: 0.18) : Color.white)
                                .cornerRadius(5)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black, lineWidth: 1.2))
                                .shadow(color: .black, radius: 0, x: 1, y: 1)
                        }
                        .buttonStyle(.plain)
                        .help("Inspect Domain Intelligence")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color(red: 1.00, green: 0.95, blue: 0.85) : Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.black : Color.black.opacity(0.8), lineWidth: isSelected ? 2 : 1.2))
                    .shadow(color: isSelected ? .black : .black.opacity(0.5), radius: 0, x: 1.5, y: 1.5)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if selectedItem?.id == item.id {
                                selectedItem = nil
                            } else {
                                selectedItem = item
                            }
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    private func categoryIcon(for category: StorageCategory) -> String {
        switch category {
        case .xcode: return "hammer.fill"
        case .docker: return "shippingbox.fill"
        case .node: return "cube.box.fill"
        case .gradle: return "cup.and.saucer.fill"
        case .homebrew: return "mug.fill"
        case .ruby: return "diamond.fill"
        case .jvm: return "coffee.fill"
        case .rust: return "gearshape.2.fill"
        case .llm: return "brain.head.profile"
        case .mlFrameworks: return "waveform.path.ecg"
        case .pythonEnv: return "terminal.fill"
        case .backups: return "externaldrive.fill.badge.icloud"
        default: return "doc.fill"
        }
    }

    private func categoryColor(for category: StorageCategory) -> Color {
        switch category {
        case .xcode: return Color(red: 0.35, green: 0.75, blue: 1.0)
        case .docker: return Color.cyan
        case .node: return Color(red: 0.22, green: 0.78, blue: 0.52)
        case .gradle: return Color.orange
        case .homebrew: return Color.yellow
        case .ruby: return Color.red
        case .jvm: return Color(red: 0.55, green: 0.35, blue: 0.15)
        case .rust: return Color.orange
        case .llm: return Color.purple
        case .mlFrameworks: return Color(red: 0.7, green: 0.2, blue: 0.9)
        case .pythonEnv: return Color.teal
        case .backups: return Color.indigo
        default: return Color(red: 1.00, green: 0.72, blue: 0.18)
        }
    }
}
