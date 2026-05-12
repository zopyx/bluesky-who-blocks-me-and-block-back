import SwiftUI

extension ListDetailView {
    struct ListMembersSection: View {
        @ObservedObject var viewModel: ListDetailViewModel
        @Binding var memberSearchQuery: String
        let currentList: BlueskyList
        let account: AppAccount
        let appPassword: String
        let syncSnapshot: () -> Void

        @EnvironmentObject var accountStore: AccountStore
        @EnvironmentObject var blueskyClient: LiveBlueskyClient
        @EnvironmentObject var workspaceStore: ModerationWorkspaceStore

        var body: some View {
            findMembersSection
            membersSection
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
    }
}
