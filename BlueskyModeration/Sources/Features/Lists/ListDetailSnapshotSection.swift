import SwiftUI

extension ListDetailView {
    struct ListSnapshotSection: View {
        @ObservedObject var viewModel: ListDetailViewModel
        let snapshotSummary: ListMembershipSnapshotSummary?
        @Binding var selectedNewerSnapshotID: UUID?
        @Binding var selectedOlderSnapshotID: UUID?
        let snapshotHistory: [ListMembershipSnapshot]
        let selectedSnapshotComparison: ListMembershipSnapshotSummary?

        @EnvironmentObject var accountStore: AccountStore
        @EnvironmentObject var blueskyClient: LiveBlueskyClient
        @EnvironmentObject var workspaceStore: ModerationWorkspaceStore

        @State private var showingSnapshotHelp = false

        var body: some View {
            Group {
                snapshotContent
                operationLogContent
            }
            .sheet(isPresented: $showingSnapshotHelp) {
                NavigationStack {
                    List {
                        HelpSection(
                            title: loc("list.snapshot.help_about"),
                            bulletPoints: [
                                loc("list.snapshot.help_1"),
                                loc("list.snapshot.help_2"),
                                loc("list.snapshot.help_3"),
                                loc("list.snapshot.help_4"),
                                loc("list.snapshot.help_5"),
                            ]
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                    .navigationTitle(loc("list.snapshot.help_title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(loc("actions.done")) { showingSnapshotHelp = false }
                                .accessibilityHint("Closes the snapshot help screen")
                        }
                    }
                }
            }
        }

        @ViewBuilder
        private var snapshotContent: some View {
            if let snapshotSummary {
                DisclosureGroup {
                    if let previousCaptureDate = snapshotSummary.previousCaptureDate {
                        Text(verbatim: loc("list.snapshot.previous").replacingOccurrences(of: "{date}", with: previousCaptureDate.formatted(date: .abbreviated, time: .shortened)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(verbatim: loc("list.snapshot.current").replacingOccurrences(of: "{date}", with: snapshotSummary.currentCaptureDate.formatted(date: .abbreviated, time: .shortened)))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    snapshotSummaryView(snapshotSummary)

                    if snapshotHistory.count > 1 {
                        Picker(loc("list.snapshot.newer"), selection: $selectedNewerSnapshotID) {
                            ForEach(snapshotHistory, id: \.id) { snapshot in
                                Text(snapshot.capturedAt.formatted(date: .abbreviated, time: .shortened))
                                    .tag(Optional(snapshot.id))
                            }
                        }
                        .accessibilityHint("Select the newer snapshot for comparison")

                        Picker(loc("list.snapshot.older"), selection: $selectedOlderSnapshotID) {
                            ForEach(snapshotHistory, id: \.id) { snapshot in
                                Text(snapshot.capturedAt.formatted(date: .abbreviated, time: .shortened))
                                    .tag(Optional(snapshot.id))
                            }
                        }
                        .accessibilityHint("Select the older snapshot for comparison")

                        if let selectedSnapshotComparison {
                            Divider()
                            Text(verbatim: loc("list.snapshot.what_changed"))
                                .font(.subheadline.weight(.semibold))
                            snapshotSummaryView(selectedSnapshotComparison)
                        }
                    }
                } label: {
                    HStack {
                        Text(verbatim: loc("list.snapshot.title"))
                        Spacer()
                        Button {
                            showingSnapshotHelp = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(Color.skyPrimary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Help with snapshots")
                        .accessibilityHint("Explains how snapshots track membership changes over time")
                    }
                }
            }
        }

        @ViewBuilder
        private var operationLogContent: some View {
            if !workspaceStore.operationLog.isEmpty {
                Section {
                    ForEach(workspaceStore.operationLog.prefix(5)) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.title)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(entry.createdAt, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.summary)
                            if !entry.failedHandles.isEmpty {
                                Text(verbatim: loc("list.snapshot.failed").replacingOccurrences(of: "{handles}", with: entry.failedHandles.joined(separator: ", ")))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text(verbatim: loc("list.snapshot.recent_ops"))
                }
            }
        }

        private func snapshotSummaryView(_ summary: ListMembershipSnapshotSummary) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                if summary.hasChanges {
                    if !summary.addedMembers.isEmpty {
                        Text(verbatim: loc("list.snapshot.added").replacingOccurrences(of: "{handles}", with: summary.addedMembers.map(\.handle).joined(separator: ", ")))
                    }

                    if !summary.removedMembers.isEmpty {
                        Text(verbatim: loc("list.snapshot.removed").replacingOccurrences(of: "{handles}", with: summary.removedMembers.map(\.handle).joined(separator: ", ")))
                    }
                } else {
                    Text(verbatim: loc("list.snapshot.no_changes"))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
    }
}
