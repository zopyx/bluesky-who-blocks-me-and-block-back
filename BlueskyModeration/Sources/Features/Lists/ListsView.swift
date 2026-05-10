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
    @State private var showProfile = false
    @State private var showFollowers = false
    @State private var showFollowing = false
    @State private var showBlocking = false
    @State private var showBlockedBy = false
    @State private var isShowingBulkLookup = false

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
                    VStack(spacing: 28) {
                        Image("RulyxLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 100)

                        ProgressView()
                            .controlSize(.large)
                            .scaleEffect(1.5)

                        Text("Loading your data\u{2026}")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if let activeAccount = accountStore.activeAccount {
                            Section {
                                Button {
                                    showProfile = true
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
                            .navigationDestination(isPresented: $showProfile) {
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
                                    showFollowers = true
                                } label: {
                                    relationshipRow(
                                        icon: "person.3",
                                        label: "Followers",
                                        count: viewModel.activeProfile?.followersCount ?? 0
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showFollowing = true
                                } label: {
                                    relationshipRow(
                                        icon: "person.3.fill",
                                        label: "Following",
                                        count: viewModel.activeProfile?.followsCount ?? 0
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showBlocking = true
                                } label: {
                                    relationshipRow(
                                        icon: "hand.raised",
                                        label: "Blocking",
                                        count: viewModel.blockingCount
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showBlockedBy = true
                                } label: {
                                    relationshipRow(
                                        icon: "hand.raised.slash",
                                        label: "Blocked by",
                                        count: viewModel.blockedByCount
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text("Relationships")
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
                        .navigationDestination(isPresented: $showBlocking) {
                            RelationshipsView(mode: .blocking, initialCount: viewModel.blockingCount)
                                .environmentObject(accountStore)
                                .environmentObject(blueskyClient)
                        }
                        .navigationDestination(isPresented: $showBlockedBy) {
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
                                            .accessibilityLabel("\(list.name), \(list.memberCount ?? 0) members")
                                    }
                                }
                            } else {
                                Button {
                                    createListKind = .moderation
                                    isShowingCreateList = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.tertiary)
                                        Text("Create first moderation list")
                                            .font(.subheadline)
                                            .foregroundStyle(.tertiary)
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        } header: {
                            sectionHeader(title: "Moderation Lists", icon: "checklist.checked", kind: .moderation)
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
                                            .accessibilityLabel("\(list.name), \(list.memberCount ?? 0) members")
                                    }
                                }
                            } else {
                                Button {
                                    createListKind = .regular
                                    isShowingCreateList = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.tertiary)
                                        Text("Create first list")
                                            .font(.subheadline)
                                            .foregroundStyle(.tertiary)
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        } header: {
                            sectionHeader(title: "Lists", icon: "list.bullet", kind: .regular)
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
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("RulyxLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                }

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
                    Menu {
                        Button { isShowingBulkLookup = true } label: {
                            Label("Bulk Lookup", systemImage: "magnifyingglass.circle")
                        }

                        NavigationLink {
                            DashboardView().environmentObject(accountStore).environmentObject(workspaceStore)
                        } label: {
                            Label("Dashboard", systemImage: "chart.bar")
                        }

                        NavigationLink {
                            ActivityLogView().environmentObject(workspaceStore)
                        } label: {
                            Label("Activity Log", systemImage: "clock.arrow.circlepath")
                        }

                        NavigationLink {
                            ActionPresetsView()
                        } label: {
                            Label("Action Presets", systemImage: "square.2.layers.3d")
                        }

                        NavigationLink {
                            ModerationRulesView()
                        } label: {
                            Label("Rules Engine", systemImage: "wand.and.rays")
                        }

                        NavigationLink {
                            NetworkGraphView()
                                .environmentObject(accountStore)
                                .environmentObject(blueskyClient)
                        } label: {
                            Label("Network Graph", systemImage: "point.3.connected.trianglepath.dotted")
                        }

                        NavigationLink {
                            FollowerDiffView()
                                .environmentObject(accountStore)
                                .environmentObject(blueskyClient)
                        } label: {
                            Label("Follower Diff", systemImage: "person.2.badge.plusminus")
                        }

                        NavigationLink {
                            TrendDetectionView()
                                .environmentObject(accountStore)
                                .environmentObject(blueskyClient)
                        } label: {
                            Label("Trend Detection", systemImage: "chart.xyaxis.line")
                        }

                        NavigationLink {
                            ReportGeneratorView()
                                .environmentObject(accountStore)
                                .environmentObject(workspaceStore)
                        } label: {
                            Label("Generate Report", systemImage: "doc.text")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
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
            .sheet(isPresented: $isShowingBulkLookup) {
                NavigationStack {
                    BulkProfileLookupView()
                        .environmentObject(accountStore)
                        .environmentObject(blueskyClient)
                }
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

    private func sectionHeader(title: String, icon: String, kind: BlueskyList.Kind) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(kind == .moderation ? .orange : .skyPrimary)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .textCase(.none)
            Spacer()
            Button {
                createListKind = kind
                isShowingCreateList = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(kind == .moderation ? .orange : .skyPrimary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
        }
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
