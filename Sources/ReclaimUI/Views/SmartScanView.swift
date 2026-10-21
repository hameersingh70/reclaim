// SmartScanView.swift
// ReclaimUI/Views
//
// Premium CleanMyMac-quality Smart Scan interface.
// Features: live disk ring, animated radar scan, expandable category cards,
// risk-colored items, and a prominent one-click Clean to Trash action bar.

import SwiftUI
import AppKit
import Reclaim

// MARK: - Smart Scan View

public struct SmartScanView: View {
    @ObservedObject public var appState: AppState
    public let theme: any Theme
    public let onStartScan: () -> Void
    public let onStopScan: () -> Void
    public let onExecuteClean: () -> Void
    public let onDeleteItem: (StorageItem) -> Void
    public var onOpenStorageManager: (() -> Void)? = nil

    @State private var spinAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var expandedCategories: Set<StorageCategory> = []

    public init(
        appState: AppState,
        theme: any Theme,
        onStartScan: @escaping () -> Void,
        onStopScan: @escaping () -> Void,
        onExecuteClean: @escaping () -> Void,
        onDeleteItem: @escaping (StorageItem) -> Void,
        onOpenStorageManager: (() -> Void)? = nil
    ) {
        self.appState = appState
        self.theme = theme
        self.onStartScan = onStartScan
        self.onStopScan = onStopScan
        self.onExecuteClean = onExecuteClean
        self.onDeleteItem = onDeleteItem
        self.onOpenStorageManager = onOpenStorageManager
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    switch appState.scanPhase {
                    case .idle:
                        if let receipt = appState.lastReceipt {
                            celebrationView(receipt)
                        } else {
                            idleHeroView
                        }

                    case .scanning(let progress):
                        scanningView(progress)

                    case .complete:
                        resultsView

                    case .failed(let msg):
                        errorView(msg)
                    }
                }
                .padding(.bottom, appState.selectedBytes > 0 ? 90 : 0)
            }
            .background(theme.windowBackground)

            // Floating action bar — only visible when items selected
            if appState.selectedBytes > 0, case .complete = appState.scanPhase {
                cleanActionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: appState.selectedBytes)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: 1. Idle Hero
    // ─────────────────────────────────────────────────────────────

    @ViewBuilder
    private var idleHeroView: some View {
        neoBrutalistIdleHeroView
    }

    private var neoBrutalistIdleHeroView: some View {
        VStack(spacing: 24) {
            // Top Hero Banner (Neo-Brutalist Retro Pop)
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("RECLAIM OS")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                                .foregroundColor(.black)
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1.5))

                            Text("DEV STORAGE INTELLIGENCE")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 0.40, green: 0.40, blue: 0.45))
                        }

                        Text("Reclaim your disk.\nPurge bloated dev waste.")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 0.08, green: 0.08, blue: 0.10))
                            .lineSpacing(2)

                        Text("Instant, non-destructive trash-first cleanup for HuggingFace models, Docker buildkits, node_modules, and Xcode caches.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.40))
                            .frame(maxWidth: 480)
                    }

                    Spacer()

                    // Retro Circular Badge (Like the pink/purple stamp in reference)
                    ZStack {
                        Circle()
                            .fill(Color(red: 1.00, green: 0.40, blue: 0.42))
                            .frame(width: 88, height: 88)
                            .overlay(Circle().stroke(Color.black, lineWidth: 2.5))
                            .offset(x: 4, y: 4)

                        VStack(spacing: 2) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                            Text("100% SAFE")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 12)
                }

                // Primary Start Scan Button (Neo-Brutal Coral Button with hard black shadow)
                HStack(spacing: 16) {
                    Button(action: onStartScan) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13))
                            Text("RUN SMART SCAN NOW")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Color(red: 1.00, green: 0.40, blue: 0.42)) // Coral
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                        .shadow(color: .black, radius: 0, x: 3, y: 3)
                    }
                    .buttonStyle(.plain)

                    if let onOpenStorage = onOpenStorageManager {
                        Button(action: onOpenStorage) {
                            HStack(spacing: 6) {
                                Image(systemName: "internaldrive.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("macOS STORAGE")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                            .shadow(color: .black, radius: 0, x: 3, y: 3)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(Color(red: 0.22, green: 0.78, blue: 0.52))
                        Text("SSH, AWS, .env & fine-tuned checkpoints immune")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.30, green: 0.30, blue: 0.35))
                    }
                }
                .padding(.top, 4)
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black, lineWidth: 2.5))
            .shadow(color: .black, radius: 0, x: 4, y: 4)
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // Chunky Stat Banner (Directly matches the warm Amber 200+ 1200+ 700+ card from reference!)
            HStack(spacing: 0) {
                neoStatBlock(number: "12+", label: "Toolchains Supported", color: .black)
                Divider().frame(width: 2).background(Color.black)
                neoStatBlock(number: "2.7+ GB", label: "Typical Instant Reclaim", color: .black)
                Divider().frame(width: 2).background(Color.black)
                neoStatBlock(number: "0-Risk", label: "Trash-First Safe Recovery", color: .black)
            }
            .padding(.vertical, 14)
            .background(Color(red: 1.00, green: 0.72, blue: 0.18)) // Vibrant warm amber (#FFB82E)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black, lineWidth: 2.5))
            .shadow(color: .black, radius: 0, x: 4, y: 4)
            .padding(.horizontal, 24)

            // Ecosystem Cards Grid (Neo-Brutalist Pop Cards)
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Monitored Hotspots")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 0.08, green: 0.08, blue: 0.10))
                    Spacer()
                    Text("POSIX fts Inode Traversal")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.50))
                }
                .padding(.horizontal, 24)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    neoModuleCard(icon: "brain.head.profile", tag: "AI / ML", title: "LLM Weights", desc: "HuggingFace Hub, Ollama blobs, LM Studio, Whisper checkpoints", color: Color(red: 1.00, green: 0.45, blue: 0.48))
                    neoModuleCard(icon: "shippingbox.fill", tag: "CONTAINERS", title: "Docker Builds", desc: "BuildKit caches, untagged images, dangling layers, VMs", color: Color(red: 0.35, green: 0.75, blue: 1.00))
                    neoModuleCard(icon: "cube.box.fill", tag: "NODE / WEB", title: "Node & Test Caches", desc: "node_modules, Playwright browsers, npm & yarn tarballs", color: Color(red: 0.40, green: 0.88, blue: 0.60))
                    neoModuleCard(icon: "hammer.fill", tag: "APPLE DEV", title: "Xcode Build Data", desc: "DerivedData, device support symbols, old simulator runtimes", color: Color(red: 1.00, green: 0.75, blue: 0.25))
                    neoModuleCard(icon: "terminal.fill", tag: "PYTHON", title: "Python Envs & uv", desc: "Astral uv wheel cache, conda envs, poetry, __pycache__", color: Color(red: 0.70, green: 0.50, blue: 0.98))
                    neoModuleCard(icon: "cup.and.saucer.fill", tag: "JVM / BREW", title: "Build Packages", desc: "Gradle caches, Homebrew bottles, Maven m2, old JDKs", color: Color(red: 1.00, green: 0.60, blue: 0.30))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .background(theme.windowBackground)
    }

    private func neoStatBlock(number: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(number)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(color.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    private func neoModuleCard(icon: String, tag: String, title: String, desc: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tag)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1.5))

                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
            }

            Text(title)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(.black)

            Text(desc)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color.black.opacity(0.75))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(color)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
        .shadow(color: .black, radius: 0, x: 3, y: 3)
    }

    private var standardIdleHeroView: some View {
        VStack(spacing: 0) {
            // Top gradient hero band
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.06, blue: 0.18), Color(red: 0.1, green: 0.12, blue: 0.28)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 28) {
                    Spacer().frame(height: 32)

                    // Pulsing scan orb
                    Button(action: onStartScan) {
                        ZStack {
                            // Outer pulse ring
                            Circle()
                                .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                                .frame(width: 210, height: 210)
                                .scaleEffect(pulseScale)
                                .animation(
                                    .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                    value: pulseScale
                                )

                            // Middle ring
                            Circle()
                                .stroke(Color.blue.opacity(0.35), lineWidth: 1.5)
                                .frame(width: 185, height: 185)

                            // Main orb
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color(red: 0.2, green: 0.5, blue: 1.0),
                                            Color(red: 0.1, green: 0.25, blue: 0.75)
                                        ],
                                        center: .center,
                                        startRadius: 10,
                                        endRadius: 80
                                    )
                                )
                                .frame(width: 160, height: 160)
                                .shadow(color: Color.blue.opacity(0.5), radius: 24, x: 0, y: 8)

                            // Inner content
                            VStack(spacing: 8) {
                                Image(systemName: "bolt.shield.fill")
                                    .font(.system(size: 42, weight: .medium))
                                    .foregroundColor(.white)
                                Text("Smart Scan")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white.opacity(0.95))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .onAppear { pulseScale = 1.05 }

                    // Headlines
                    VStack(spacing: 8) {
                        Text("Developer Storage Intelligence")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)

                        Text("Pinpoints reclaimable space in Xcode, Docker, Node.js,\nGradle, Homebrew — never your source files or secrets.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    // Capability chips
                    HStack(spacing: 12) {
                        CapabilityChip(icon: "bolt.fill", label: "POSIX fts Engine", color: .orange)
                        CapabilityChip(icon: "lock.shield.fill", label: "SafetyEngine", color: .green)
                        CapabilityChip(icon: "trash.circle.fill", label: "Trash-First", color: .blue)
                    }
                    .padding(.bottom, 36)
                }
            }
            .frame(height: 450)

            // What we scan — informational cards
            VStack(alignment: .leading, spacing: 16) {
                Text("What We Analyze")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                    .padding(.top, 24)
                    .padding(.horizontal, 32)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    WhatWeCleanCard(icon: "hammer.fill", title: "Xcode", subtitle: "DerivedData, device symbols, simulator runtimes", color: .blue)
                    WhatWeCleanCard(icon: "shippingbox.fill", title: "Docker", subtitle: "BuildKit cache, dangling layers", color: .cyan)
                    WhatWeCleanCard(icon: "cube.box.fill", title: "Node.js", subtitle: "node_modules, npm / yarn / pnpm caches", color: .green)
                    WhatWeCleanCard(icon: "cup.and.saucer.fill", title: "Gradle", subtitle: "Dependency caches, wrapper distributions", color: .orange)
                    WhatWeCleanCard(icon: "mug.fill", title: "Homebrew", subtitle: "Downloaded formula tarballs", color: .yellow)
                    WhatWeCleanCard(icon: "lock.shield.fill", title: "Protected Always", subtitle: "SSH keys, AWS creds, .env files", color: .purple)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(theme.windowBackground)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: 2. Scanning
    // ─────────────────────────────────────────────────────────────

    private func scanningView(_ progress: ScanProgress) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 22) {
                Spacer().frame(height: 28)

                // Neo-Brutalist Radar / Progress Gauge
                ZStack {
                    Circle()
                        .stroke(Color.black, lineWidth: 3)
                        .frame(width: 130, height: 130)

                    Circle()
                        .trim(from: 0.0, to: 0.65)
                        .stroke(
                            Color(red: 1.00, green: 0.72, blue: 0.18), // Amber
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 130, height: 130)
                        .rotationEffect(.degrees(spinAngle))
                        .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: spinAngle)
                        .onAppear { spinAngle = 360 }
                        .onDisappear { spinAngle = 0 }

                    VStack(spacing: 2) {
                        Text("\(progress.filesScanned)")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                        Text("TARGETS")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundColor(Color.black.opacity(0.6))
                    }
                }

                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(red: 0.22, green: 0.78, blue: 0.52))
                            .frame(width: 8, height: 8)
                        Text("ACTIVE APFS INODE TRAVERSAL")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(Color.black.opacity(0.75))
                    }

                    Text(progress.currentPath.isEmpty
                         ? "Inspecting developer cache roots"
                         : shortenPath(progress.currentPath))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .frame(maxWidth: 520)

                    if progress.bytesIndexed > 0 {
                        Text("DISCOVERED: \(ByteCountFormatter.string(fromByteCount: progress.bytesIndexed, countStyle: .file))")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                            .foregroundColor(.black)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                            .padding(.top, 4)
                    }
                }

                Button(action: onStopScan) {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("HALT SCAN")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color(red: 1.00, green: 0.40, blue: 0.42))
                    .foregroundColor(.black)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                    .shadow(color: .black, radius: 0, x: 3, y: 3)
                }
                .buttonStyle(.plain)

                Spacer().frame(height: 28)
            }
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black, lineWidth: 2.5))
            .shadow(color: .black, radius: 0, x: 4, y: 4)
            .padding(24)
        }
        .background(theme.windowBackground)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: 3. Results
    // ─────────────────────────────────────────────────────────────

    private var resultsView: some View {
        VStack(spacing: 16) {
            // Summary header (Neo-Brutalist Card)
            resultsSummaryHeader
                .padding(.horizontal, 20)
                .padding(.top, 16)

            // Selection buttons row
            selectionToolbar
                .padding(.horizontal, 20)

            // Category cards
            VStack(spacing: 8) {
                let activeCategories = StorageCategory.allCases.filter { cat in
                    appState.storageItems.contains(where: { $0.category == cat })
                }
                ForEach(activeCategories, id: \.self) { category in
                    let items = appState.storageItems.filter { $0.category == category }
                    if !items.isEmpty {
                        CategoryResultCard(
                            category: category,
                            items: items,
                            appState: appState,
                            theme: theme,
                            isExpanded: expandedCategories.contains(category),
                            onToggleExpand: {
                                if expandedCategories.contains(category) {
                                    expandedCategories.remove(category)
                                } else {
                                    expandedCategories.insert(category)
                                }
                            },
                            onDeleteItem: onDeleteItem
                        )
                    }
                }
            }
            .padding(.horizontal, 20)

            // Safety guarantee footer
            safetyFooter
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
    }

    private var resultsSummaryHeader: some View {
        HStack(spacing: 20) {
            // Total found
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("SCAN COMPLETE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.22, green: 0.78, blue: 0.52)) // Mint
                        .foregroundColor(.black)
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 1.2))

                    Text("\(appState.storageItems.count) ITEMS INDEXED")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(Color.black.opacity(0.6))
                }

                Text(ByteCountFormatter.string(
                    fromByteCount: appState.storageItems.reduce(0) { $0 + $1.estimatedReclaimableSize },
                    countStyle: .file))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.black)

                Text("Total safe reclaimable space across all detected toolchains")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.65))
            }

            Spacer()

            // Mini disk ring
            DiskRingView(
                reclaimable: appState.storageItems.reduce(0) { $0 + $1.estimatedReclaimableSize },
                total: totalDiskCapacity(),
                theme: theme
            )
            .frame(width: 80, height: 80)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
        .shadow(color: .black, radius: 0, x: 3, y: 3)
    }

    private var selectionToolbar: some View {
        HStack(spacing: 10) {
            Button(action: { appState.selectAllSafe() }) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.shield.fill")
                    Text("Select Safe")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(red: 0.22, green: 0.78, blue: 0.52)) // Mint
                .foregroundColor(.black)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                .shadow(color: .black, radius: 0, x: 2, y: 2)
            }
            .buttonStyle(.plain)

            Button(action: { appState.selectAll() }) {
                HStack(spacing: 5) {
                    Image(systemName: "checklist")
                    Text("Select All")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                .shadow(color: .black, radius: 0, x: 2, y: 2)
            }
            .buttonStyle(.plain)

            Button(action: { appState.deselectAll() }) {
                HStack(spacing: 5) {
                    Image(systemName: "xmark.square")
                    Text("Clear Selection")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                .shadow(color: .black, radius: 0, x: 2, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("\(appState.selectedItemIDs.count) SELECTED")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                .foregroundColor(.black)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
        }
    }

    private var safetyFooter: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(Color(red: 0.22, green: 0.78, blue: 0.52))
                .font(.system(size: 16))
            Text("SafetyEngine Active: SSH keys, AWS credentials, .env files, git branches, and fine-tuned checkpoints permanently immune.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color.black.opacity(0.75))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 1.5))
        .shadow(color: .black, radius: 0, x: 2, y: 2)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: 4. Floating Clean Bar
    // ─────────────────────────────────────────────────────────────

    private var cleanActionBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("READY TO RECLAIM")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(Color.black.opacity(0.6))
                Text(appState.formattedSelectedBytes)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.black)
            }

            Spacer()

            Button(action: onExecuteClean) {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 13))
                    Text("MOVE SELECTED TO TRASH (SAFE)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(Color(red: 1.00, green: 0.40, blue: 0.42)) // Coral
                .foregroundColor(.black)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                .shadow(color: .black, radius: 0, x: 3, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black, lineWidth: 2.5))
        .shadow(color: .black, radius: 0, x: 4, y: 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: 5. Celebration
    // ─────────────────────────────────────────────────────────────

    private func celebrationView(_ receipt: CleanupReceipt) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Spacer().frame(height: 16)

                ZStack {
                    Circle()
                        .fill(Color(red: 0.22, green: 0.78, blue: 0.52)) // Mint
                        .frame(width: 72, height: 72)
                        .overlay(Circle().stroke(Color.black, lineWidth: 2.5))
                        .shadow(color: .black, radius: 0, x: 3, y: 3)

                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.black)
                }

                VStack(spacing: 4) {
                    Text("CLEANUP SUCCESSFUL!")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                    Text("\(receipt.formattedRecovered) safely moved to macOS Trash")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color.black.opacity(0.7))
                }

                Spacer().frame(height: 8)
            }
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black, lineWidth: 2.5))
            .shadow(color: .black, radius: 0, x: 4, y: 4)
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Actions list
            VStack(alignment: .leading, spacing: 10) {
                Text("Cleaned Items Audit")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)

                VStack(spacing: 6) {
                    ForEach(receipt.actions.prefix(8), id: \.path) { action in
                        HStack(spacing: 10) {
                            Image(systemName: action.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(action.success ? Color(red: 0.22, green: 0.78, blue: 0.52) : Color(red: 1.00, green: 0.72, blue: 0.18))
                                .font(.system(size: 14))

                            Text(URL(fileURLWithPath: action.path).lastPathComponent)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                                .lineLimit(1)

                            Spacer()

                            Text(ByteCountFormatter.string(fromByteCount: action.reclaimedBytes, countStyle: .file))
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
                    }
                }
                .padding(.horizontal, 20)

                if receipt.actions.count > 8 {
                    Text("+ \(receipt.actions.count - 8) more items...")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color.black.opacity(0.6))
                        .padding(.horizontal, 24)
                }
            }

            Button(action: {
                appState.lastReceipt = nil
                appState.resetScan()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                    Text("RUN NEW SMART SCAN")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(Color(red: 1.00, green: 0.40, blue: 0.42)) // Coral
                .foregroundColor(.black)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                .shadow(color: .black, radius: 0, x: 3, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 32)
        }
        .background(theme.windowBackground)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: 6. Error
    // ─────────────────────────────────────────────────────────────

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundColor(.red.opacity(0.8))
            Text("Scan Failed")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(theme.textPrimary)
            Text(message)
                .font(.callout)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button("Try Again", action: onStartScan)
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.windowBackground)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: Helpers
    // ─────────────────────────────────────────────────────────────

    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func totalDiskCapacity() -> Int64 {
        let url = URL(fileURLWithPath: "/")
        let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey])
        return Int64(values?.volumeTotalCapacity ?? 500_000_000_000)
    }
}

// MARK: - Category Result Card (Expandable)

private struct CategoryResultCard: View {
    let category: StorageCategory
    let items: [StorageItem]
    @ObservedObject var appState: AppState
    let theme: any Theme
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onDeleteItem: (StorageItem) -> Void

    private var totalBytes: Int64 { items.reduce(0) { $0 + $1.estimatedReclaimableSize } }
    private var selectedCount: Int { items.filter { appState.isSelected($0.id) }.count }
    private var allSelected: Bool { selectedCount == items.count }
    private var someSelected: Bool { selectedCount > 0 && !allSelected }

    var body: some View {
        VStack(spacing: 0) {
            // Row header (Neo-Brutalist Card)
            Button(action: onToggleExpand) {
                HStack(spacing: 14) {
                    // Category checkbox (Neo-Brutalist square checkbox)
                    Button {
                        let ids = Set(items.map(\.id))
                        if allSelected {
                            appState.selectedItemIDs.subtract(ids)
                        } else {
                            appState.selectedItemIDs.formUnion(ids)
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(allSelected ? Color.black : Color.white)
                                .frame(width: 20, height: 20)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 2))

                            if allSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.white)
                            } else if someSelected {
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: 10, height: 3)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    // Icon (Solid black outline badge)
                    categoryIconView
                        .frame(width: 32, height: 32)
                        .background(categoryColor)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))

                    // Labels
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.displayName)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                        Text("\(items.count) item\(items.count == 1 ? "" : "s")  ·  \(selectedCount) selected")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color.black.opacity(0.6))
                    }

                    Spacer()

                    // Size Pill Badge
                    Text(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(red: 1.00, green: 0.72, blue: 0.18))
                        .foregroundColor(.black)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))

                    // Folder Opener Button (Neo-Brutal White Button)
                    if let firstItem = items.first {
                        let folderPath: String = {
                            var isDir: ObjCBool = false
                            if FileManager.default.fileExists(atPath: firstItem.path, isDirectory: &isDir), isDir.boolValue {
                                return firstItem.path
                            }
                            return URL(fileURLWithPath: firstItem.path).deletingLastPathComponent().path
                        }()

                        Button {
                            NSWorkspace.shared.open(URL(fileURLWithPath: folderPath))
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 11))
                                Text("Open")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                            .shadow(color: .black, radius: 0, x: 2, y: 2)
                        }
                        .buttonStyle(.plain)
                        .help("Open in Finder (\(folderPath))")
                    }

                    // Direct Delete Category Selection Button (Neo-Brutal Coral Button)
                    Button {
                        let targets = items.filter { appState.isSelected($0.id) }
                        guard !targets.isEmpty else { return }
                        for item in targets {
                            onDeleteItem(item)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 11))
                            Text(selectedCount > 0 ? "Delete (\(selectedCount))" : "Delete")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(selectedCount > 0 ? Color(red: 1.00, green: 0.40, blue: 0.42) : Color.black.opacity(0.1))
                        .foregroundColor(selectedCount > 0 ? .black : Color.black.opacity(0.4))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                        .shadow(color: selectedCount > 0 ? .black : .clear, radius: 0, x: 2, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedCount == 0)

                    // Chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
            .shadow(color: .black, radius: 0, x: 3, y: 3)
            .padding(.horizontal, 20)
            .padding(.vertical, 4)

            // Expanded items
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(items, id: \.id) { item in
                        ItemRow(item: item, appState: appState, theme: theme, onDelete: { onDeleteItem(item) })
                        if item.id != items.last?.id {
                            Divider().background(Color.black.opacity(0.1))
                                .padding(.leading, 56)
                        }
                    }
                }
                .padding(.vertical, 8)
                .background(Color(red: 0.96, green: 0.94, blue: 0.90))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 1.5))
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
    }

    @ViewBuilder
    private var categoryIconView: some View {
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

    private var categoryColor: Color {
        switch category {
        case .xcode:        return .blue
        case .docker:       return .cyan
        case .node:         return .green
        case .gradle:       return .orange
        case .homebrew:     return .yellow
        case .ruby:         return .red
        case .jvm:          return Color(red: 0.55, green: 0.35, blue: 0.15)
        case .rust:         return .orange
        case .llm:          return .purple
        case .mlFrameworks: return Color(red: 0.7, green: 0.2, blue: 0.9)
        case .pythonEnv:    return .teal
        case .backups:      return .indigo
        case .downloads:    return .blue
        default:            return .gray
        }
    }
}

// MARK: - Item Row

private struct ItemRow: View {
    let item: StorageItem
    @ObservedObject var appState: AppState
    let theme: any Theme
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox (Neo-Brutalist square)
            Button { appState.toggleSelection(for: item.id) } label: {
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
            .padding(.leading, 18)

            // Name + path
            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: item.path).lastPathComponent)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .lineLimit(1)

                Text(shortenPath(item.path))
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
                .frame(minWidth: 64, alignment: .trailing)

            // Open Folder Button (Neo-Brutal Mini Button)
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

            // Direct Delete Button (Neo-Brutal Mini Coral Button)
            Button(action: onDelete) {
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
            .padding(.trailing, 16)
        }
        .padding(.vertical, 7)
    }

    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}

// MARK: - Disk Ring View

private struct DiskRingView: View {
    let reclaimable: Int64
    let total: Int64
    let theme: any Theme

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1.0, Double(reclaimable) / Double(total))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.12), lineWidth: 8)

            Circle()
                .trim(from: 0, to: CGFloat(fraction))
                .stroke(
                    Color(red: 1.00, green: 0.72, blue: 0.18), // Amber
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: fraction)

            VStack(spacing: 1) {
                Text(String(format: "%.0f%%", fraction * 100))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                Text("WASTE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundColor(Color.black.opacity(0.6))
            }
        }
    }
}

// MARK: - Capability Chip

private struct CapabilityChip: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
    }
}

// MARK: - What We Clean Card

private struct WhatWeCleanCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
}
