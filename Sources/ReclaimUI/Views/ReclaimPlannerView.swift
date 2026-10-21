// ReclaimPlannerView.swift
// ReclaimUI/Views
//
// Reclaim Planner interface allowing developers to set a target space goal
// and preview lowest-risk cleanup plans per PRD §17 and §18.

import SwiftUI
import Reclaim

public struct ReclaimPlannerView: View {
    @ObservedObject public var appState: AppState
    public let theme: any Theme

    @State private var targetGB: String = "10"
    @State private var generatedPlan: ReclaimPlan? = nil
    @State private var dryRunReport: DryRunReport? = nil

    private let engine = RecommendationEngine()
    private let executor = CleanupExecutor(useTrash: true)

    public init(appState: AppState, theme: any Theme) {
        self.appState = appState
        self.theme = theme
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reclaim Planner")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(theme.textPrimary)

            HStack {
                Text("I need to free:")
                    .foregroundColor(theme.textPrimary)
                TextField("GB", text: $targetGB)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                Text("GB")
                    .foregroundColor(theme.textSecondary)

                Button("Generate Plan") {
                    if let gb = Double(targetGB) {
                        let targetBytes = Int64(gb * 1_073_741_824)
                        let plan = engine.createPlan(targetBytes: targetBytes, items: appState.storageItems)
                        self.generatedPlan = plan
                        self.dryRunReport = executor.dryRun(plan: plan)
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            if let plan = generatedPlan, let report = dryRunReport {
                Divider()

                HStack {
                    Text("Plan Status:")
                        .fontWeight(.semibold)
                    Text(plan.isTargetMet ? "Target Met" : "Insufficient Safe Storage")
                        .foregroundColor(plan.isTargetMet ? theme.safeStatus : theme.mediumRiskStatus)

                    Spacer()

                    Text("Total Reclaimable: \(report.formattedReclaimable)")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                }

                Text("Candidates in Plan:")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)

                List(report.items, id: \.path) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.path)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .foregroundColor(theme.textPrimary)
                            Text(item.reason)
                                .font(.caption2)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        RiskBadge(risk: item.risk, theme: theme)

                        Text(ByteCountFormatter.string(fromByteCount: item.allocatedSize, countStyle: .file))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(theme.textPrimary)
                    }
                    .padding(.vertical, 2)
                }
            } else {
                Spacer()
                Text("Enter a target amount and click Generate Plan to find the lowest-risk items to delete.")
                    .font(.callout)
                    .foregroundColor(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            }
        }
        .padding(16)
        .background(theme.windowBackground)
    }
}
