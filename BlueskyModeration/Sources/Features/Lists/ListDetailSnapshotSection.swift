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
                            title: "About Snapshots",
                            bulletPoints: [
                                "Snapshots capture the full membership of this list at a point in time.",
                                "Use the pickers to compare two historical snapshots and see what changed.",
                                "New snapshots are created automatically after bulk operations.",
                                "The diff shows exactly which members were added or removed between snapshots.",
                                "Snapshots are stored locally and tied to this workspace."
                            ]
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                    .navigationTitle("Snapshots Help")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSnapshotHelp = false }
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
                        Text("Previous snapshot: \(previousCaptureDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Current snapshot: \(snapshotSummary.currentCaptureDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    snapshotSummaryView(snapshotSummary)

                    if snapshotHistory.count > 1 {
                        Picker("Newer Snapshot", selection: $selectedNewerSnapshotID) {
                            ForEach(snapshotHistory, id: \.id) { snapshot in
                                Text(snapshot.capturedAt.formatted(date: .abbreviated, time: .shortened))
                                    .tag(Optional(snapshot.id))
                            }
                        }

                        Picker("Older Snapshot", selection: $selectedOlderSnapshotID) {
                            ForEach(snapshotHistory, id: \.id) { snapshot in
                                Text(snapshot.capturedAt.formatted(date: .abbreviated, time: .shortened))
                                    .tag(Optional(snapshot.id))
                            }
                        }

                        if let selectedSnapshotComparison {
                            Divider()
                            Text("What Changed Since")
                                .font(.subheadline.weight(.semibold))
                            snapshotSummaryView(selectedSnapshotComparison)
                        }
                    }
                } label: {
                    HStack {
                        Text("Snapshot History")
                        Spacer()
                        Button {
                            showingSnapshotHelp = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(Color.skyPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }

        @ViewBuilder
        private var operationLogContent: some View {
            if !workspaceStore.operationLog.isEmpty {
                Section("Recent Operations") {
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
                                Text("Failed: \(entry.failedHandles.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }

        private func snapshotSummaryView(_ summary: ListMembershipSnapshotSummary) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                if summary.hasChanges {
                    if !summary.addedMembers.isEmpty {
                        Text("Added: \(summary.addedMembers.map(\.handle).joined(separator: ", "))")
                    }

                    if !summary.removedMembers.isEmpty {
                        Text("Removed: \(summary.removedMembers.map(\.handle).joined(separator: ", "))")
                    }
                } else {
                    Text("No membership changes in this comparison.")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
    }
}
