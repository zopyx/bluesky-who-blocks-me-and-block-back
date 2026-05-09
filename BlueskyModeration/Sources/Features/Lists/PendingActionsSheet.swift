import SwiftUI

struct PendingActionsSheet: View {
    @EnvironmentObject private var workspaceStore: ModerationWorkspaceStore
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                if workspaceStore.queuedActions.isEmpty {
                    ContentUnavailableView(
                        "No Pending Actions",
                        systemImage: "tray",
                        description: Text("Long-running operations like blocking followers will appear here.")
                    )
                } else {
                    ForEach(workspaceStore.queuedActions) { action in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(action.title)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                statusBadge(action.status)
                            }

                            switch action.status {
                            case .pending:
                                Text("Waiting to start\u{2026}")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            case .running(let done, let total, let handle):
                                ProgressView(value: Double(done), total: Double(total))
                                Text("\(done) of \(total)\(handle.map { " \u{2014} \($0)" } ?? "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            case .completed(let succeeded, let failed):
                                if failed > 0 {
                                    Text("\(succeeded) succeeded, \(failed) failed")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("\(succeeded) completed")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if case .pending = action.status {
                                Button("Cancel", role: .destructive) {
                                    workspaceStore.actionQueue.cancel(action.id)
                                }
                                .font(.caption)
                            }
                            if case .completed = action.status {
                                Button("Retry") {
                                    workspaceStore.actionQueue.retry(action.id)
                                }
                                .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            workspaceStore.actionQueue.cancel(workspaceStore.queuedActions[index].id)
                        }
                    }
                }
            }
            .navigationTitle("Pending Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func statusBadge(_ status: QueuedActionStatus) -> some View {
        switch status {
        case .pending:
            Text("Pending")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(.secondary)
        case .running:
            Text("Running")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.skyPrimary.opacity(0.12), in: Capsule())
                .foregroundStyle(Color.skyPrimary)
        case .completed(let succeeded, let failed):
            if failed > 0 {
                Text("\(succeeded)/\(succeeded+failed)")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12), in: Capsule())
                    .foregroundStyle(.orange)
            } else {
                Text("Done")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.12), in: Capsule())
                    .foregroundStyle(.green)
            }
        }
    }
}
