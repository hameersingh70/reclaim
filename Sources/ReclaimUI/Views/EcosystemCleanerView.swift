// EcosystemCleanerView.swift
// ReclaimUI/Views
//
// Dedicated module cleaner view for individual developer toolchains (Xcode, Docker,
// Node.js, Gradle, Homebrew) with sub-category filters, checkboxes, and direct Finder actions.

import SwiftUI
import AppKit
import Reclaim

public struct EcosystemCleanerView: View {
    public let category: StorageCategory
    @ObservedObject public var appState: AppState
    public let theme: any Theme
    public let onScanCategory: () -> Void
    public let onDeleteItem: (StorageItem) -> Void

    public init(
        category: StorageCategory,
        appState: AppState,
        theme: any Theme,
        onScanCategory: @escaping () -> Void,
        onDeleteItem: @escaping (StorageItem) -> Void
    ) {
        self.category = category
        self.appState = appState
        self.theme = theme
        self.onScanCategory = onScanCategory
        self.onDeleteItem = onDeleteItem
    }

    private var categoryItems: [StorageItem] {
        appState.storageItems.filter { $0.category == category }
    }

    private var totalBytes: Int64 {
        categoryItems.reduce(0) { $0 + $1.allocatedSize }
    }

    private var selectedBytes: Int64 {
        categoryItems.filter { appState.isSelected($0.id) }.reduce(0) { $0 + $1.estimatedReclaimableSize }
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header Bar (Neo-Brutalist Card)
            HStack(spacing: 16) {
                categoryIcon
                    .font(.system(size: 22, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(categoryBadgeColor)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 2))
                    .shadow(color: .black, radius: 0, x: 2, y: 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(category.displayName)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.black)

                    Text(categorySubtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color.black.opacity(0.65))
                }

                Spacer()

                // Scan this Category button (Neo-Brutal Coral Button)
                Button(action: onScanCategory) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("SCAN MODULE")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(red: 1.00, green: 0.40, blue: 0.42)) // Coral
                    .foregroundColor(.black)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                    .shadow(color: .black, radius: 0, x: 2.5, y: 2.5)
                }
                .buttonStyle(.plain)

                if category == .node || category == .pythonEnv {
                    Button(action: {
                        promptAndScanCustomFolder()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("SCAN WORKSPACE FOLDER")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                        .shadow(color: .black, radius: 0, x: 2, y: 2)
                    }
                    .buttonStyle(.plain)
                    .help("Choose any project directory to discover \(category == .node ? "node_modules" : "Python virtual environments")")
                }

                // Total Bytes Badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                        .foregroundColor(.black)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))

                    Text("\(categoryItems.count) items")
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

            // Sub-actions toolbar (Neo-Brutal Action Bar)
            HStack(spacing: 10) {
                Text("\(categoryItems.filter { appState.isSelected($0.id) }.count) of \(categoryItems.count) selected (\(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file)))")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.7))

                Spacer()

                Button("Select All") {
                    let ids = Set(categoryItems.map(\.id))
                    appState.selectedItemIDs.formUnion(ids)
                }
                .font(.system(size: 11, weight: .black, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                .buttonStyle(.plain)

                Button("Deselect") {
                    let ids = Set(categoryItems.map(\.id))
                    appState.selectedItemIDs.subtract(ids)
                }
                .font(.system(size: 11, weight: .black, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                .buttonStyle(.plain)

                // Clean Selected in this Category
                Button {
                    let selected = categoryItems.filter { appState.isSelected($0.id) }
                    for item in selected {
                        onDeleteItem(item)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 10))
                        Text("Delete Selected")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(categoryItems.filter { appState.isSelected($0.id) }.isEmpty ? Color.black.opacity(0.1) : Color(red: 1.00, green: 0.40, blue: 0.42))
                    .foregroundColor(categoryItems.filter { appState.isSelected($0.id) }.isEmpty ? Color.black.opacity(0.4) : .black)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                    .shadow(color: categoryItems.filter { appState.isSelected($0.id) }.isEmpty ? .clear : .black, radius: 0, x: 2, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(categoryItems.filter { appState.isSelected($0.id) }.isEmpty)
            }
            .padding(.horizontal, 20)

            // Items List / Empty State
            if categoryItems.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.22, green: 0.78, blue: 0.52)) // Mint
                            .frame(width: 64, height: 64)
                            .overlay(Circle().stroke(Color.black, lineWidth: 2))
                            .shadow(color: .black, radius: 0, x: 3, y: 3)

                        Image(systemName: "checkmark")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.black)
                    }

                    Text("No \(category.displayName) waste found")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.black)

                    Text("Click 'Scan Module' above to search for reclaimable data in this toolchain.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color.black.opacity(0.65))

                    Button(action: onScanCategory) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                            Text("Scan \(category.displayName) Now")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                        .foregroundColor(.black)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                        .shadow(color: .black, radius: 0, x: 2, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
                .shadow(color: .black, radius: 0, x: 3, y: 3)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(categoryItems, id: \.id) { item in
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

                                // Path and Info
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(URL(fileURLWithPath: item.path).lastPathComponent)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(.black)

                                    Text(item.path)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(Color.black.opacity(0.6))
                                        .lineLimit(1)

                                    if let what = item.whatIsThis {
                                        Text(what)
                                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                                            .foregroundColor(Color(red: 0.20, green: 0.45, blue: 0.85))
                                    }
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
                                .help("Delete this item immediately to Trash")
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
        }
        .background(theme.windowBackground)
    }

    private var categoryBadgeColor: Color {
        switch category {
        case .xcode:        return Color(red: 0.35, green: 0.75, blue: 1.0)
        case .docker:       return Color(red: 0.35, green: 0.85, blue: 0.85)
        case .node:         return Color(red: 0.40, green: 0.88, blue: 0.60)
        case .gradle:       return Color(red: 1.00, green: 0.72, blue: 0.18)
        case .homebrew:     return Color(red: 1.00, green: 0.85, blue: 0.30)
        case .ruby:         return Color(red: 1.00, green: 0.40, blue: 0.42)
        case .jvm:          return Color(red: 0.85, green: 0.65, blue: 0.45)
        case .rust:         return Color(red: 0.95, green: 0.50, blue: 0.20)
        case .llm:          return Color(red: 0.70, green: 0.50, blue: 0.98)
        case .mlFrameworks: return Color(red: 0.90, green: 0.45, blue: 0.75)
        case .pythonEnv:    return Color(red: 0.45, green: 0.80, blue: 0.75)
        case .backups:      return Color(red: 0.55, green: 0.60, blue: 0.95)
        case .downloads:    return Color(red: 0.35, green: 0.75, blue: 1.0)
        default:            return Color.gray.opacity(0.3)
        }
    }

    @ViewBuilder
    private var categoryIcon: some View {
        switch category {
        case .xcode:        Image(systemName: "hammer.fill").foregroundColor(.blue)
        case .docker:       Image(systemName: "shippingbox.fill").foregroundColor(.cyan)
        case .node:         Image(systemName: "cube.box.fill").foregroundColor(.green)
        case .gradle:       Image(systemName: "cup.and.saucer.fill").foregroundColor(.orange)
        case .homebrew:     Image(systemName: "mug.fill").foregroundColor(.yellow)
        case .ruby:         Image(systemName: "diamond.fill").foregroundColor(.red)
        case .jvm:          Image(systemName: "coffee.fill").foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.15))
        case .rust:         Image(systemName: "gearshape.2.fill").foregroundColor(.orange)
        case .llm:          Image(systemName: "brain.head.profile").foregroundColor(.purple)
        case .mlFrameworks: Image(systemName: "waveform.path.ecg").foregroundColor(Color(red: 0.7, green: 0.2, blue: 0.9))
        case .pythonEnv:    Image(systemName: "terminal.fill").foregroundColor(.teal)
        case .backups:      Image(systemName: "externaldrive.fill.badge.icloud").foregroundColor(.indigo)
        case .downloads:    Image(systemName: "arrow.down.circle.fill").foregroundColor(.blue)
        default:            Image(systemName: "folder.fill").foregroundColor(.gray)
        }
    }

    private var categorySubtitle: String {
        switch category {
        case .xcode:        return "DerivedData, device symbols, and simulator runtimes"
        case .docker:       return "BuildKit cache, dangling layers, and container volumes"
        case .node:         return "Project node_modules and global npm / yarn / pnpm caches"
        case .gradle:       return "Dependency caches, wrapper distributions, and daemon logs"
        case .homebrew:     return "Cached formula downloads and stale Cellar versions"
        case .ruby:         return "rbenv/rvm rubies, gem caches, and Bundler build cache"
        case .jvm:          return "Old JDKs, Kotlin/Native prebuilts, Coursier and SBT caches"
        case .rust:         return "Cargo target build caches, incremental compilation, and registry files"
        case .llm:          return "Ollama, LM Studio, Hugging Face Hub, and GGUF checkpoints"
        case .mlFrameworks: return "PyTorch, Triton, TensorFlow, Keras, ONNX & DVC artifacts"
        case .pythonEnv:    return "pyenv versions, conda packages, pip cache, and __pycache__"
        case .backups:      return "iOS/iPadOS MobileSync device backups and local archives"
        case .downloads:    return "Heavy downloaded installers (.dmg, .pkg, .iso, .zip)"
        default:            return "Detected storage items"
        }
    }

    private func promptAndScanCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan Folder"
        panel.message = "Choose a project directory to discover \(category == .node ? "node_modules" : "Python virtual environments")"
        if panel.runModal() == .OK, let selectedURL = panel.url {
            let items = ProjectWorkspaceScanner.scanWorkspaces(
                roots: [selectedURL],
                scanNode: category == .node,
                scanPython: category == .pythonEnv,
                maxDepth: 5
            )
            appState.appendItems(items)
            let sz = items.reduce(0) { $0 + $1.allocatedSize }
            let szStr = ByteCountFormatter.string(fromByteCount: sz, countStyle: .file)
            appState.appendTerminalLog("[custom:scan] Discovered \(items.count) \(category == .node ? "node_modules" : "virtualenv") folders in \(selectedURL.lastPathComponent): \(szStr)", level: .success)
        }
    }
}
