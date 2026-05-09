import SwiftUI

struct ReportGeneratorView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var workspaceStore: ModerationWorkspaceStore
    @State private var reportText = ""
    @State private var includeStats = true

    var body: some View {
        List {
            Section {
                Toggle("Include operation stats", isOn: $includeStats)
            }

            if !reportText.isEmpty {
                Section("Preview") {
                    Text(reportText).font(.caption.monospaced())
                }

                Section {
                    ShareLink(item: reportText, subject: Text("Moderation Report")) {
                        Label("Share Report", systemImage: "square.and.arrow.up")
                    }
                }
            }

            Section {
                Button("Generate Report") {
                    generateReport()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Moderation Report")
    }

    private func generateReport() {
        var lines: [String] = []
        lines.append("# Moderation Report")
        lines.append("Generated: \(Date.now.formatted(date: .complete, time: .shortened))")
        lines.append("")

        let log = workspaceStore.operationLog
        if includeStats {
            let totalOps = log.count
            let totalSuccess = log.reduce(0) { $0 + $1.succeededHandles.count }
            let totalFailed = log.reduce(0) { $0 + $1.failedHandles.count }
            lines.append("## Summary")
            lines.append("- Total operations: \(totalOps)")
            lines.append("- Total accounts actioned: \(totalSuccess)")
            lines.append("- Total failures: \(totalFailed)")
            lines.append("")

            let byType = Dictionary(grouping: log, by: \.title)
                .mapValues(\.count)
                .sorted { $0.value > $1.value }
            lines.append("## Operations by Type")
            for (type, count) in byType {
                lines.append("- \(type): \(count)")
            }
            lines.append("")
        }

        lines.append("## Recent Activity")
        for entry in log.prefix(10) {
            lines.append("- \(entry.title): \(entry.summary) (\(entry.createdAt.formatted(date: .abbreviated, time: .shortened)))")
        }

        reportText = lines.joined(separator: "\n")
    }
}

#Preview {
    NavigationStack { ReportGeneratorView().environmentObject(ModerationWorkspaceStore(preview: true)) }
}
