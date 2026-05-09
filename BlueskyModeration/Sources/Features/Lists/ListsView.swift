import SwiftUI

struct ListsView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @EnvironmentObject private var workspaceStore: ModerationWorkspaceStore
    @StateObject private var viewModel = ListsViewModel()
    @State private var isShowingAccountPicker = false
    @State private var isShowingPendingActions = false
    @State private var isShowingCreateList = false
    @State private var createListKind: BlueskyList.Kind = .moderation
    @State private var showFollowers = false
    @State private var showFollowing = false

    var body: some View {
        NavigationStack {
            Group {
                if accountStore.accounts.isEmpty {
                    ContentUnavailableView(
                        "No Active Account",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Add a Bluesky account in the Accounts tab to load lists.")
                    )
                } else if viewModel.isLoading {
                    VStack(spacing: 20) {
                        Image(systemName: "checklist.checked")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.skyPrimary)
                            .symbolEffect(.pulse, options: .repeating)

                        ProgressView()
                            .controlSize(.large)

                        Text("Loading lists\u{2026}")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if let activeAccount = accountStore.activeAccount {
                            Section {
                                NavigationLink {
                                    BlueskyProfileView(
                                        member: activeAccountMember(activeAccount),
                                        list: nil
                                    )
                                } label: {
                                    AccountSummaryCard(
                                        account: activeAccount,
                                        avatarURL: viewModel.activeProfile?.avatarURL
                                    )
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .listRowBackground(Color.clear)
                            }
                        }

                        Section("Relationships") {
                            HStack {
                                Button {
                                    showFollowers = true
                                } label: {
                                    Label("\(viewModel.activeProfile?.followersCount ?? 0) followers", systemImage: "person.3")
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Button {
                                    showFollowing = true
                                } label: {
                                    Label("\(viewModel.activeProfile?.followsCount ?? 0) following", systemImage: "person.3.fill")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .navigationDestination(isPresented: $showFollowers) {
                            RelationshipsView(mode: .followers, initialCount: viewModel.activeProfile?.followersCount)
                                .environmentObject(accountStore)
                                .environmentObject(blueskyClient)
                        }
                        .navigationDestination(isPresented: $showFollowing) {
                            RelationshipsView(mode: .following, initialCount: viewModel.activeProfile?.followsCount)
                                .environmentObject(accountStore)
                                .environmentObject(blueskyClient)
                        }

                        if let lists = groupedLists[.moderation], !lists.isEmpty {
                            Section {
                                ForEach(lists) { list in
                                    NavigationLink {
                                        ListDetailView(list: list) { updatedList in
                                            viewModel.updateList(updatedList)
                                        }
                                    } label: {
                                        ListRowView(list: list)
                                            .accessibilityLabel("\(list.name), \(list.memberCount ?? 0) members")
                                    }
                                }
                            } header: {
                                HStack {
                                    Text("Moderation Lists")
                                    Spacer()
                                    Button {
                                        createListKind = .moderation
                                        isShowingCreateList = true
                                    } label: {
                                        Image(systemName: "plus")
                                    }
                                }
                            }
                        }

                        if let lists = groupedLists[.regular], !lists.isEmpty {
                            Section {
                                ForEach(lists) { list in
                                    NavigationLink {
                                        ListDetailView(list: list) { updatedList in
                                            viewModel.updateList(updatedList)
                                        }
                                    } label: {
                                        ListRowView(list: list)
                                            .accessibilityLabel("\(list.name), \(list.memberCount ?? 0) members")
                                    }
                                }
                            } header: {
                                HStack {
                                    Text("Lists")
                                    Spacer()
                                    Button {
                                        createListKind = .regular
                                        isShowingCreateList = true
                                    } label: {
                                        Image(systemName: "plus")
                                    }
                                }
                            }
                        }

                        if let errorMessage = viewModel.errorMessage {
                            ErrorRetryBanner(message: errorMessage) {
                                viewModel.errorMessage = nil
                                Task {
                                    await reload()
                                }
                            }
                        }
                    }
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await reload()
                    }
                }
            }
            .navigationTitle("RULYX")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let activeAccount = accountStore.activeAccount {
                        Button {
                            isShowingAccountPicker = true
                        } label: {
                            AccountChip(
                                account: activeAccount,
                                avatarURL: viewModel.activeProfile?.avatarURL
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Switch active account")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await reload()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh lists")
                    .disabled(accountStore.activeAccount == nil)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingPendingActions = true
                    } label: {
                        Label("Pending Actions", systemImage: "clock.arrow.circlepath")
                    }
                    .disabled(workspaceStore.queuedActions.isEmpty)
                }
            }
            .sheet(isPresented: $isShowingAccountPicker) {
                AccountSwitcherSheet(isPresented: $isShowingAccountPicker)
                    .environmentObject(accountStore)
            }
            .sheet(isPresented: $isShowingPendingActions) {
                PendingActionsSheet(isPresented: $isShowingPendingActions)
                    .environmentObject(workspaceStore)
            }
            .sheet(isPresented: $isShowingCreateList) {
                CreateListSheet(kind: createListKind) { name, description, kind in
                    if let account = accountStore.activeAccount,
                       let appPassword = accountStore.appPassword(for: account) {
                        Task {
                            do {
                                let newList = try await blueskyClient.createList(
                                    name: name,
                                    description: description,
                                    kind: kind,
                                    account: account,
                                    appPassword: appPassword
                                )
                                viewModel.addList(newList)
                            } catch {
                                viewModel.errorMessage = AppError.userMessage(from: error)
                            }
                        }
                    }
                }
                .environmentObject(accountStore)
                .environmentObject(blueskyClient)
            }
            .task(id: accountStore.activeAccountID) {
                await reload()
            }

        }
    }

    private var groupedLists: [BlueskyList.Kind: [BlueskyList]] {
        viewModel.listsByKind
    }

    private func reload() async {
        let password = accountStore.activeAccount.flatMap { accountStore.appPassword(for: $0) }
        await viewModel.load(
            for: accountStore.activeAccount,
            appPassword: password,
            using: blueskyClient
        )
    }

    private func activeAccountMember(_ account: AppAccount) -> BlueskyListMember {
        BlueskyListMember(
            recordURI: "account:\(account.id.uuidString)",
            actor: BlueskyActor(
                did: account.did ?? account.handle,
                handle: account.handle,
                displayName: account.displayName,
                avatarURL: viewModel.activeProfile?.avatarURL
            )
        )
    }
}

#Preview {
    ListsView()
        .environmentObject(AccountStore(preview: true))
        .environmentObject(PreviewBlueskyClient())
}
