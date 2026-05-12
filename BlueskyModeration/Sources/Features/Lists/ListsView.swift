import SwiftUI

struct ListsView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @EnvironmentObject private var workspaceStore: ModerationWorkspaceStore
    @EnvironmentObject private var localizationManager: LocalizationManager
    @StateObject private var viewModel = ListsViewModel()
    @State private var presentationState = PresentationState()

    var body: some View {
        NavigationStack {
            Group {
                if accountStore.accounts.isEmpty {
                    EmptyStatePanel(
                        title: localizationManager.localized("lists.no_account.title"),
                        message: localizationManager.localized("lists.no_account.desc")
                    )
                } else if viewModel.isLoading {
                    LoadingPanel(message: localizationManager.localized("lists.loading"))
                } else {
                    List {
                        if let activeAccount = accountStore.activeAccount {
                            Section {
                                Button {
                                    presentationState.showProfile = true
                                } label: {
                                    AccountSummaryCard(
                                        account: activeAccount,
                                        avatarURL: viewModel.activeProfile?.avatarURL
                                    )
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .listRowBackground(Color.clear)
                            }
                            .navigationDestination(isPresented: $presentationState.showProfile) {
                                BlueskyProfileView(
                                    member: activeAccountMember(activeAccount),
                                    list: nil
                                )
                                .environmentObject(accountStore)
                                .environmentObject(blueskyClient)
                            }
                        }

                        Section {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading) {
                                Button {
                                    presentationState.showFollowers = true
                                } label: {
                                    relationshipRow(
                                        icon: "person.3",
                                        label: loc("lists.followers"),
                                        count: viewModel.activeProfile?.followersCount ?? 0
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    presentationState.showFollowing = true
                                } label: {
                                    relationshipRow(
                                        icon: "person.3.fill",
                                        label: loc("lists.following"),
                                        count: viewModel.activeProfile?.followsCount ?? 0
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    presentationState.showBlocking = true
                                } label: {
                                    relationshipRow(
                                        icon: "hand.raised",
                                        label: loc("lists.blocking"),
                                        count: viewModel.blockingCount
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    presentationState.showBlockedBy = true
                                } label: {
                                    relationshipRow(
                                        icon: "hand.raised.slash",
                                        label: loc("lists.blocked_by"),
                                        count: viewModel.blockedByCount
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text(loc("lists.relationships"))
                        }
                        .navigationDestination(isPresented: $presentationState.showFollowers) {
                            RelationshipsView(mode: .followers, initialCount: viewModel.activeProfile?.followersCount)
                                .environmentObject(accountStore)
                                .environmentObject(blueskyClient)
                        }
                        .navigationDestination(isPresented: $presentationState.showFollowing) {
                            RelationshipsView(mode: .following, initialCount: viewModel.activeProfile?.followsCount)
                                .environmentObject(accountStore)
                                .environmentObject(blueskyClient)
                        }
                        .navigationDestination(isPresented: $presentationState.showBlocking) {
                            RelationshipsView(mode: .blocking, initialCount: viewModel.blockingCount)
                                .environmentObject(accountStore)
                                .environmentObject(blueskyClient)
                        }
                        .navigationDestination(isPresented: $presentationState.showBlockedBy) {
                            RelationshipsView(mode: .blockedBy, initialCount: viewModel.blockedByCount)
                                .environmentObject(accountStore)
                                .environmentObject(blueskyClient)
                        }

                        Section {
                            if let lists = viewModel.listsByKind[.moderation], !lists.isEmpty {
                                ForEach(lists) { list in
                                    NavigationLink {
                                        ListDetailView(list: list) { updatedList in
                                            viewModel.updateList(updatedList)
                                        }
                                    } label: {
                                        ListRowView(list: list)
                                            .accessibilityLabel(loc("list.row.label").replacingOccurrences(of: "{name}", with: list.name).replacingOccurrences(of: "{count}", with: "\(list.memberCount ?? 0)"))
                                    }
                                }
                            } else {
                                Button {
                                    presentationState.createListKind = .moderation
                                    presentationState.isShowingCreateList = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.tertiary)
                                        Text(loc("lists.create_first_mod"))
                                            .font(.subheadline)
                                            .foregroundStyle(.tertiary)
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        } header: {
                            Text(loc("lists.moderation_lists"))
                        }

                        Section {
                            if let lists = viewModel.listsByKind[.regular], !lists.isEmpty {
                                ForEach(lists) { list in
                                    NavigationLink {
                                        ListDetailView(list: list) { updatedList in
                                            viewModel.updateList(updatedList)
                                        }
                                    } label: {
                                        ListRowView(list: list)
                                            .accessibilityLabel(loc("list.row.label").replacingOccurrences(of: "{name}", with: list.name).replacingOccurrences(of: "{count}", with: "\(list.memberCount ?? 0)"))
                                    }
                                }
                            } else {
                                Button {
                                    presentationState.createListKind = .regular
                                    presentationState.isShowingCreateList = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.tertiary)
                                        Text(loc("lists.create_first"))
                                            .font(.subheadline)
                                            .foregroundStyle(.tertiary)
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        } header: {
                            Text(loc("lists.lists"))
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
                    .dynamicTypeSize(DynamicTypeSize.xSmall...DynamicTypeSize.accessibility1)
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await reload()
                    }
                }
            }
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await reload()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel(loc("lists.refresh.label"))
                    .disabled(accountStore.activeAccount == nil)
                }
            }
            .sheet(isPresented: $presentationState.isShowingAccountPicker) {
                AccountSwitcherSheet(isPresented: $presentationState.isShowingAccountPicker)
                    .environmentObject(accountStore)
            }

            .sheet(isPresented: $presentationState.isShowingBulkLookup) {
                NavigationStack {
                    BulkProfileLookupView()
                        .environmentObject(accountStore)
                        .environmentObject(blueskyClient)
                }
            }
            .sheet(isPresented: $presentationState.isShowingCreateList) {
                CreateListSheet(kind: presentationState.createListKind) { name, description, kind in
                    if let account = accountStore.activeAccount,
                       let appPassword = accountStore.appPassword(for: account)
                    {
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
            .sheet(isPresented: $presentationState.isShowingAccountManagement) {
                NavigationStack {
                    AccountSwitcherSheet(isPresented: $presentationState.isShowingAccountManagement)
                        .environmentObject(accountStore)
                        .environmentObject(blueskyClient)
                }
            }
            .task(id: accountStore.activeAccountID) {
                await reload()
            }
        }
    }

    private func reload() async {
        let password = accountStore.activeAccount.flatMap { accountStore.appPassword(for: $0) }
        await viewModel.load(
            for: accountStore.activeAccount,
            appPassword: password,
            using: blueskyClient
        )
    }

    private func relationshipRow(icon: String, label: String, count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text("\(count)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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

    private func openAccountManagement() {
        presentationState.isShowingAccountManagement = true
    }
}

#Preview {
    ListsView()
        .environmentObject(AccountStore(preview: true))
        .environmentObject(PreviewBlueskyClient())
}
