import SwiftUI

extension ListDetailView {
    struct ListMembersSection: View {
        @ObservedObject var viewModel: ListDetailViewModel
        @Binding var memberSearchQuery: String
        let currentList: BlueskyList
        let account: AppAccount
        let appPassword: String
        @Binding var isShowingBulkRemoveConfirmation: Bool
        let syncSnapshot: () -> Void

        @EnvironmentObject var accountStore: AccountStore
        @EnvironmentObject var blueskyClient: LiveBlueskyClient
        @EnvironmentObject var workspaceStore: ModerationWorkspaceStore

        var body: some View {
            findMembersSection
            membersSection
        }

        private var findMembersSection: some View {
            Section("Find Existing Members") {
                TextField("Filter current members", text: $memberSearchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Filter members by handle or name")

                if !viewModel.members.isEmpty {
                    Text(viewModel.loadedMemberSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    bulkRemoveToolbar
                }

                if !memberSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("\(viewModel.filteredMembers.count) matching members")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        @ViewBuilder
        private var membersSection: some View {
            Section("Members") {
                if viewModel.isLoadingMembers && viewModel.members.isEmpty {
                    LoadingPanel(message: "Loading members\u{2026}")
                } else if let errorMsg = viewModel.membersErrorMessage, viewModel.members.isEmpty {
                    ErrorRetryBanner(message: errorMsg) {
                        Task {
                            await viewModel.loadMembers(
                                for: currentList,
                                account: account,
                                appPassword: appPassword,
                                using: blueskyClient
                            )
                        }
                    }
                } else if viewModel.members.isEmpty {
                    EmptyStatePanel(
                        title: "No Members Yet",
                        message: "Search for accounts above to add to this list."
                    )
                } else if viewModel.filteredMembers.isEmpty {
                    EmptyStatePanel(
                        title: "No Matches",
                        message: "No existing members match the current filter."
                    )
                } else {
                    ForEach(viewModel.filteredMembers) { member in
                        HStack(spacing: 12) {
                            Button {
                                viewModel.toggleMemberSelection(for: member)
                            } label: {
                                Image(systemName: viewModel.isSelectedForBulkRemoval(member) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(viewModel.isSelectedForBulkRemoval(member) ? Color.skyPrimary : Color.secondary.opacity(0.45))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(viewModel.isSelectedForBulkRemoval(member) ? "Deselect \(member.actor.handle)" : "Select \(member.actor.handle)")

                            NavigationLink {
                                BlueskyProfileView(member: member, list: currentList)
                            } label: {
                                BlueskyActorRow(actor: member.actor)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.remove(
                                            member: member,
                                            account: account,
                                            appPassword: appPassword,
                                            using: blueskyClient
                                        )
                                        syncSnapshot()
                                    }
                                } label: {
                                    Label("Remove", systemImage: "person.crop.circle.badge.minus")
                                }
                                .disabled(viewModel.isRemoving(member) || viewModel.isPerformingBulkAction)
                                .accessibilityHint("This action cannot be undone.")
                            }
                        }
                    }

                    if viewModel.isLoadingMoreMembers {
                        HStack {
                            ProgressView()
                            Text("Loading more members")
                                .foregroundStyle(.secondary)
                        }
                    } else if viewModel.hasMoreMembers {
                        Button("Load More Members") {
                            Task {
                                await viewModel.loadMoreMembersIfNeeded(
                                    currentMember: viewModel.filteredMembers.last,
                                    list: currentList,
                                    account: account,
                                    appPassword: appPassword,
                                    using: blueskyClient
                                )
                            }
                        }
                        .accessibilityLabel("Load more list members")
                    }
                }
            }
        }

        private var bulkRemoveToolbar: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button(viewModel.selectedMemberIDs.count == viewModel.filteredMembers.count && !viewModel.filteredMembers.isEmpty ? "Clear Visible Selection" : "Select Visible Members") {
                        if viewModel.selectedMemberIDs.count == viewModel.filteredMembers.count && !viewModel.filteredMembers.isEmpty {
                            viewModel.clearMemberSelection()
                        } else {
                            viewModel.selectAllFilteredMembers()
                        }
                    }
                    .disabled(viewModel.isPerformingBulkAction || viewModel.filteredMembers.isEmpty)
                    .accessibilityLabel(viewModel.selectedMemberIDs.count == viewModel.filteredMembers.count && !viewModel.filteredMembers.isEmpty ? "Clear visible selection" : "Select all visible members")

                    Spacer()

                    if !viewModel.selectedMemberIDs.isEmpty {
                        Text("\(viewModel.selectedMemberIDs.count) selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button(role: .destructive) {
                    isShowingBulkRemoveConfirmation = true
                } label: {
                    Label("Remove Selected Members", systemImage: "person.crop.circle.badge.minus")
                }
                .disabled(viewModel.selectedMemberIDs.isEmpty || viewModel.isPerformingBulkAction)
                .accessibilityLabel("Remove selected members from list")
                .accessibilityHint("This action cannot be undone.")
            }
        }
    }
}
