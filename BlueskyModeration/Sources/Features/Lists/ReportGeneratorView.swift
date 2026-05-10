import SwiftUI

struct ReportGeneratorView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var workspaceStore: ModerationWorkspaceStore
    @State private var reportText = ""
    @State private var includeStats = true

    var body: some View {
        List {
            Section {
                Toggle(isOn: $includeStats) {
                    Text(verbatim: loc("report.include_stats"))
                }
                .accessibilityHint("Toggles whether to include statistics in the report")
            }

            if !reportText.isEmpty {
                Section {
                    Text(reportText).font(.caption.monospaced())
                } header: {
                    Text(verbatim: loc("report.preview"))
                }

                Section {
                    ShareLink(item: reportText, subject: Text(loc("report.subject"))) {
                        Label {
                            Text(verbatim: loc("report.share"))
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .accessibilityHint("Shares the generated report")
                }
            }

            Section {
                Button(loc("report.generate")) {
                    generateReport()
                }
                .accessibilityHint("Generates the moderation report")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(loc("report.title"))
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
