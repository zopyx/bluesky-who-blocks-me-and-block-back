import SwiftUI

struct ListDetailView: View {
    let list: BlueskyList

    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @StateObject private var viewModel = ListDetailViewModel()
    @State private var searchQuery = ""
    @State private var memberSearchQuery = ""

    var body: some View {
        Group {
            if let account = accountStore.activeAccount,
               let appPassword = accountStore.appPassword(for: account) {
                content(account: account, appPassword: appPassword)
            } else {
                ContentUnavailableView(
                    "Missing Credentials",
                    systemImage: "key.slash",
                    description: Text("This account no longer has a saved app password.")
                )
            }
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("List", isPresented: .constant(viewModel.errorMessage != nil), actions: {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        }, message: {
            Text(viewModel.errorMessage ?? "")
        })
    }

    @ViewBuilder
    private func content(account: AppAccount, appPassword: String) -> some View {
        List {
            Section("Search Bluesky Users") {
                TextField("Search by handle or name", text: $searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if viewModel.isSearching {
                    HStack {
                        ProgressView()
                        Text("Searching")
                            .foregroundStyle(.secondary)
                    }
                } else if !searchQuery.isEmpty && searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                    Text("Type at least 2 characters to search.")
                        .foregroundStyle(.secondary)
                } else if !viewModel.searchResults.isEmpty {
                    ForEach(viewModel.searchResults) { actor in
                        ActorSearchResultRow(
                            actor: actor,
                            isAdding: viewModel.isAdding(actor)
                        ) {
                            Task {
                                await viewModel.add(
                                    actor: actor,
                                    to: list,
                                    account: account,
                                    appPassword: appPassword,
                                    using: blueskyClient
                                )
                            }
                        }
                    }
                } else if !searchQuery.isEmpty && !viewModel.isSearching {
                    Text("No matching users found.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Find Existing Members") {
                TextField("Filter current members", text: $memberSearchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !memberSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("\(filteredMembers.count) matching members")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Members") {
                if viewModel.isLoadingMembers && viewModel.members.isEmpty {
                    HStack {
                        ProgressView()
                        Text("Loading members")
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.members.isEmpty {
                    Text("No members in this list yet.")
                        .foregroundStyle(.secondary)
                } else if filteredMembers.isEmpty {
                    Text("No existing members match this filter.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredMembers) { member in
                        NavigationLink {
                            BlueskyProfileView(member: member, list: list)
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
                                }
                            } label: {
                                Label("Remove", systemImage: "person.crop.circle.badge.minus")
                            }
                            .disabled(viewModel.isRemoving(member))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .task {
            await viewModel.loadMembers(
                for: list,
                account: account,
                appPassword: appPassword,
                using: blueskyClient
            )
        }
        .task(id: searchQuery) {
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }

            await viewModel.search(
                query: searchQuery,
                account: account,
                appPassword: appPassword,
                using: blueskyClient
            )
        }
        .refreshable {
            await viewModel.loadMembers(
                for: list,
                account: account,
                appPassword: appPassword,
                using: blueskyClient
            )
        }
    }

    private var filteredMembers: [BlueskyListMember] {
        viewModel.filteredMembers(matching: memberSearchQuery)
    }
}

#Preview {
    NavigationStack {
        ListDetailView(
            list: BlueskyList(
                id: "at://did:plc:preview/app.bsky.graph.list/123",
                name: "Trusted Sources",
                description: "Accounts curated for signal over noise.",
                memberCount: 67,
                kind: .regular
            )
        )
    }
    .environmentObject(AccountStore(preview: true))
    .environmentObject(PreviewBlueskyClient())
}
