import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var workspaceStore: ModerationWorkspaceStore

    var body: some View {
        List {
            Section("Overview") {
                let totalLists = accountStore.accounts.reduce(0) { _, _ in 0 }
                LabeledContent("Accounts", value: "\(accountStore.accounts.count)")
                LabeledContent("Total Operations", value: "\(workspaceStore.operationLog.count)")
            }

            if !workspaceStore.operationLog.isEmpty {
                Section("Operations by Type") {
                    Chart(operationCounts, id: \.0) { type, count in
                        BarMark(x: .value("Type", type), y: .value("Count", count))
                            .foregroundStyle(Color.skyPrimary.gradient)
                    }
                    .frame(height: 180)
                    .chartXAxis { AxisMarks { AxisValueLabel() } }
                }

                Section("Recent Activity") {
                    ForEach(workspaceStore.operationLog.prefix(10)) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.title).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(entry.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(entry.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("Top Moderated Accounts") {
                    let top = topModeratedAccounts()
                    if top.isEmpty {
                        Text("No moderation data yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(top.prefix(10), id: \.0) { handle, count in
                            HStack {
                                Text(handle).font(.subheadline.monospaced())
                                Spacer()
                                Text("\(count)x").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("No Data", systemImage: "chart.bar", description: Text("Start moderating to see analytics."))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Dashboard")
    }

    private var operationCounts: [(String, Int)] {
        let grouped = Dictionary(grouping: workspaceStore.operationLog, by: \.title)
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    }

    private func topModeratedAccounts() -> [(String, Int)] {
        var counts: [String: Int] = [:]
        for entry in workspaceStore.operationLog {
            for handle in entry.succeededHandles {
                counts[handle, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
    }
}

#Preview {
    NavigationStack {
        DashboardView()
            .environmentObject(AccountStore(preview: true))
            .environmentObject(ModerationWorkspaceStore(preview: true))
    }
}
