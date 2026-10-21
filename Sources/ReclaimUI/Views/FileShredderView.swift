// FileShredderView.swift
// ReclaimUI/Views
//
// Neo-brutalist secure file and folder shredder view.
// Overwrites file sectors with random cryptographic noise prior to unlinking,
// preventing recovery by data forensics tools. Protected by SafetyEngine.

import SwiftUI
import AppKit
import Reclaim

public struct FileShredderView: View {
    @ObservedObject public var appState: AppState
    public let theme: any Theme

    @State private var selectedPath: String = ""
    @State private var selectedPasses: Int = 1
    @State private var isShredding: Bool = false
    @State private var shredStatus: String? = nil
    @State private var showConfirmDialog: Bool = false

    private let shredder = FileShredderEngine()

    public init(appState: AppState, theme: any Theme) {
        self.appState = appState
        self.theme = theme
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard

                warningBanner

                selectionCard

                if !selectedPath.isEmpty {
                    targetSummaryCard
                }

                if let status = shredStatus {
                    statusCard(text: status)
                }
            }
            .padding(24)
        }
        .background(theme.windowBackground)
        .confirmationDialog(
            "Permanently Shred File?",
            isPresented: $showConfirmDialog,
            titleVisibility: .visible
        ) {
            Button("SHRED PERMANENTLY", role: .destructive) {
                executeShred()
            }
            Button("CANCEL", role: .cancel) {}
        } message: {
            Text("This action is completely IRREVERSIBLE. Data will be overwritten with cryptographic random noise and cannot be recovered even with forensics tools.")
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 44, height: 44)
                .background(Color(red: 1.00, green: 0.40, blue: 0.42))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black, lineWidth: 2))
                .shadow(color: .black, radius: 0, x: 2, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text("Secure File Shredder")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                Text("Permanently erases files using DOD 5220.22-M random pattern overwriting to prevent data recovery.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.65))
            }

            Spacer()
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
        .shadow(color: .black, radius: 0, x: 3, y: 3)
    }

    // MARK: - Warning Banner

    private var warningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)

            VStack(alignment: .leading, spacing: 2) {
                Text("NO TRASH RECOVERY")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.black)
                Text("Standard file deletion only marks space as free. File Shredder physically overwrites each storage block with random noise before unlinking. System files and developer keys are strictly protected.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.85))
            }
            Spacer()
        }
        .padding(14)
        .background(Color(red: 1.00, green: 0.85, blue: 0.30)) // Warning Yellow
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
        .shadow(color: .black, radius: 0, x: 2, y: 2)
    }

    // MARK: - Selection Card

    private var selectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SELECT TARGET TO SHRED")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(.black)

            HStack(spacing: 12) {
                Button(action: selectFile) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.fill")
                        Text("SELECT FILE...")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                    .shadow(color: .black, radius: 0, x: 2, y: 2)
                }
                .buttonStyle(.plain)

                Button(action: selectFolder) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                        Text("SELECT FOLDER...")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 1.5))
                    .shadow(color: .black, radius: 0, x: 2, y: 2)
                }
                .buttonStyle(.plain)

                Spacer()

                // Passes picker
                HStack(spacing: 6) {
                    Text("Overwrites:")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.black)

                    Picker("", selection: $selectedPasses) {
                        Text("1 Pass (Fast)").tag(1)
                        Text("3 Passes (DoD)").tag(3)
                        Text("7 Passes (Gutmann Lite)").tag(7)
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
        .shadow(color: .black, radius: 0, x: 3, y: 3)
    }

    // MARK: - Target Summary Card

    private var targetSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TARGET READY FOR SHREDDING")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(Color.black.opacity(0.6))

                    Text(selectedPath)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .lineLimit(2)
                }

                Spacer()

                Button(action: { showConfirmDialog = true }) {
                    HStack(spacing: 6) {
                        if isShredding {
                            ProgressView().controlSize(.small)
                            Text("SHREDDING...")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                        } else {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                            Text("SHRED NOW")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(red: 1.00, green: 0.40, blue: 0.42))
                    .foregroundColor(.black)
                    .cornerRadius(7)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black, lineWidth: 2))
                    .shadow(color: .black, radius: 0, x: 2.5, y: 2.5)
                }
                .buttonStyle(.plain)
                .disabled(isShredding)
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
        .shadow(color: .black, radius: 0, x: 3, y: 3)
    }

    private func statusCard(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(Color(red: 0.22, green: 0.78, blue: 0.52))
                .font(.system(size: 16))
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.black)
            Spacer()
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1.5))
        .shadow(color: .black, radius: 0, x: 2, y: 2)
    }

    // MARK: - Actions

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Select File to Shred"
        if panel.runModal() == .OK, let url = panel.url {
            selectedPath = url.path
            shredStatus = nil
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select Folder to Shred"
        if panel.runModal() == .OK, let url = panel.url {
            selectedPath = url.path
            shredStatus = nil
        }
    }

    private func executeShred() {
        let path = selectedPath
        guard !path.isEmpty else { return }

        isShredding = true
        appState.appendTerminalLog("[shredder:start] Securely shredding \(path) (\(selectedPasses) passes)...", level: .command)

        Task {
            do {
                let receipt = try shredder.shred(path: path, passes: selectedPasses)
                await MainActor.run {
                    self.isShredding = false
                    self.selectedPath = ""
                    self.shredStatus = "✓ Shredded \(receipt.filesCount) files (\(receipt.formattedBytes) overwritten)."
                    appState.appendTerminalLog("[shredder:ok] Permanently erased \(receipt.formattedBytes) (\(receipt.filesCount) files).", level: .success)
                    appState.notifyCleanupPerformed()
                }
            } catch {
                await MainActor.run {
                    self.isShredding = false
                    self.shredStatus = "Error: \(error.localizedDescription)"
                    appState.appendTerminalLog("[shredder:err] \(error.localizedDescription)", level: .error)
                }
            }
        }
    }
}
