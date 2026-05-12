import SwiftUI

enum ListBulkAction: Identifiable {
    case block, mute, unblock, unmute
    var id: Self { self }
}

extension ListDetailView {
    struct ListMembersSection: View {
        @ObservedObject var viewModel: ListDetailViewModel
        @Binding var memberSearchQuery: String
        let currentList: BlueskyList
        let account: AppAccount
        let appPassword: String
        @Binding var isShowingBulkRemoveConfirmation: Bool
        @Binding var pendingBulkAction: ListBulkAction?
        let syncSnapshot: () -> Void

        @EnvironmentObject var accountStore: AccountStore
        @EnvironmentObject var blueskyClient: LiveBlueskyClient
        @EnvironmentObject var workspaceStore: ModerationWorkspaceStore

        var body: some View {
            Group {
                findMembersSection
                membersSection
            }
            .confirmationDialog(
                loc("list.members.bulk_action_title"),
                isPresented: .init(get: { pendingBulkAction != nil }, set: { if !$0 { pendingBulkAction = nil } }),
                titleVisibility: .visible
            ) {
                if let action = pendingBulkAction {
                    Button(loc("list.members.confirm")) {
                        Task { await performBulkAction(action) }
                    }
                    Button(loc("actions.cancel"), role: .cancel) { pendingBulkAction = nil }
                }
            } message: {
                if let action = pendingBulkAction {
                    Text(verbatim: confirmationMessage(for: action))
                }
            }
        }

        private func confirmationMessage(for action: ListBulkAction) -> String {
            let count = viewModel.selectedMemberIDs.count
            switch action {
            case .block: return loc("list.members.bulk_block_message").replacingOccurrences(of: "{count}", with: "\(count)")
            case .mute: return loc("list.members.bulk_mute_message").replacingOccurrences(of: "{count}", with: "\(count)")
            case .unblock: return loc("list.members.bulk_unblock_message").replacingOccurrences(of: "{count}", with: "\(count)")
            case .unmute: return loc("list.members.bulk_unmute_message").replacingOccurrences(of: "{count}", with: "\(count)")
            }
        }

        private func performBulkAction(_ action: ListBulkAction) async {
            pendingBulkAction = nil
            switch action {
            case .block:
                await viewModel.bulkBlockSelectedMembers(account: account, appPassword: appPassword, using: blueskyClient)
            case .mute:
                await viewModel.bulkMuteSelectedMembers(account: account, appPassword: appPassword, using: blueskyClient)
            case .unblock:
                await viewModel.bulkUnblockSelectedMembers(account: account, appPassword: appPassword, using: blueskyClient)
            case .unmute:
                await viewModel.bulkUnmuteSelectedMembers(account: account, appPassword: appPassword, using: blueskyClient)
            }
            syncSnapshot()
        }

        private var findMembersSection: some View {
            Section {
                TextField(loc("list.members.filter_placeholder"), text: $memberSearchQuery)
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
                    Text(verbatim: loc("list.members.matching").replacingOccurrences(of: "{count}", with: "\(viewModel.filteredMembers.count)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(verbatim: loc("list.members.find"))
            }
        }

        @ViewBuilder
        private var membersSection: some View {
            Section {
                if viewModel.isLoadingMembers && viewModel.members.isEmpty {
                    LoadingPanel(message: loc("list.members.loading"))
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
                        title: loc("list.members.no_members"),
                        message: loc("list.members.no_members_desc")
                    )
                } else if viewModel.filteredMembers.isEmpty {
                    EmptyStatePanel(
                        title: loc("list.members.no_matches"),
                        message: loc("list.members.no_matches_desc")
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
                            .accessibilityHint(viewModel.isSelectedForBulkRemoval(member) ? "Removes this member from the selection" : "Marks this member for bulk removal")

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
                                    Label { Text(verbatim: loc("actions.remove")) } icon: { Image(systemName: "person.crop.circle.badge.minus") }
                                }
                                .disabled(viewModel.isRemoving(member) || viewModel.isPerformingBulkAction)
                                .accessibilityHint("This action cannot be undone.")
                            }
                        }
                    }

                    if viewModel.isLoadingMoreMembers {
                        HStack {
                            ProgressView()
                            Text(verbatim: loc("list.members.loading_more"))
                                .foregroundStyle(.secondary)
                        }
                    } else if viewModel.hasMoreMembers {
                        Button(loc("list.members.load_more_button")) {
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
                        .accessibilityHint("Fetches the next page of list members")
                    }
                }
            } header: {
                Text(verbatim: loc("list.members.title"))
            }
        }

        private var bulkRemoveToolbar: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button(viewModel.selectedMemberIDs.count == viewModel.filteredMembers.count && !viewModel.filteredMembers.isEmpty ? loc("list.members.clear_selection") : loc("list.members.select_visible")) {
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
                        Text(verbatim: loc("list.members.selected_count").replacingOccurrences(of: "{count}", with: "\(viewModel.selectedMemberIDs.count)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !viewModel.selectedMemberIDs.isEmpty {
                    HStack(spacing: 8) {
                        Button {
                            isShowingBulkRemoveConfirmation = true
                        } label: {
                            Label { Text(verbatim: loc("list.members.remove_selected")) } icon: { Image(systemName: "person.crop.circle.badge.minus") }
                        }
                        .disabled(viewModel.isPerformingBulkAction)
                        .font(.caption)

                        Spacer()

                        Button {
                            pendingBulkAction = .block
                        } label: {
                            Label { Text(verbatim: loc("list.members.block_selected")) } icon: { Image(systemName: "hand.raised") }
                        }
                        .disabled(viewModel.isPerformingBulkAction)
                        .font(.caption)

                        Button {
                            pendingBulkAction = .mute
                        } label: {
                            Label { Text(verbatim: loc("list.members.mute_selected")) } icon: { Image(systemName: "speaker.slash") }
                        }
                        .disabled(viewModel.isPerformingBulkAction)
                        .font(.caption)
                    }

                    HStack(spacing: 8) {
                        Button {
                            pendingBulkAction = .unblock
                        } label: {
                            Label { Text(verbatim: loc("list.members.unblock_selected")) } icon: { Image(systemName: "hand.raised.slash") }
                        }
                        .disabled(viewModel.isPerformingBulkAction)
                        .font(.caption)

                        Button {
                            pendingBulkAction = .unmute
                        } label: {
                            Label { Text(verbatim: loc("list.members.unmute_selected")) } icon: { Image(systemName: "speaker.wave.2") }
                        }
                        .disabled(viewModel.isPerformingBulkAction)
                        .font(.caption)
                    }
                }
            }
        }
    }
}
