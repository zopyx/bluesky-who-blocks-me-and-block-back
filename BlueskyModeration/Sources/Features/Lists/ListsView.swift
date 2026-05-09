import SwiftUI

struct ListsView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @EnvironmentObject private var workspaceStore: ModerationWorkspaceStore
    @StateObject private var viewModel = ListsViewModel()
    @State private var isShowingAccountPicker = false
    @State private var isShowingPendingActions = false

    var body: some View {
        NavigationStack {
            Group {
                if accountStore.accounts.isEmpty {
                    ContentUnavailableView(
                        "No Active Account",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Add a Bluesky account in the Accounts tab to load lists.")
                    )
                } else if viewModel.isLoading && groupedLists.isEmpty {
                    ProgressView("Loading Lists")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if groupedLists.isEmpty {
                    ContentUnavailableView(
                        "No Lists Found",
                        systemImage: "tray",
                        description: Text("This account has no lists or the data source returned nothing.")
                    )
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

                            dashboardSection
                        }

                        ForEach(BlueskyList.Kind.allCases, id: \.self) { kind in
                            if let lists = groupedLists[kind], !lists.isEmpty {
                                Section(kind.title) {
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
            .navigationTitle("Lists")
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
            .task(id: accountStore.activeAccountID) {
                await reload()
            }

        }
    }

    private var groupedLists: [BlueskyList.Kind: [BlueskyList]] {
        viewModel.listsByKind
    }

    private var allLists: [BlueskyList] {
        groupedLists.values
            .flatMap { $0 }
            .sorted { ($0.memberCount ?? 0) > ($1.memberCount ?? 0) }
    }

    private var largestLists: [BlueskyList] {
        Array(allLists.prefix(3))
    }

    private var dashboardSection: some View {
        Section("Dashboard") {
            if !recentListChanges.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent List Changes")
                        .font(.subheadline.weight(.semibold))

                    ForEach(recentListChanges, id: \.snapshotID) { summary in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(summary.listName)
                            Text(changeSummary(for: summary))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if !largestLists.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Largest Lists")
                        .font(.subheadline.weight(.semibold))

                    ForEach(largestLists) { list in
                        NavigationLink {
                            ListDetailView(list: list) { updatedList in
                                viewModel.updateList(updatedList)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(list.name)
                                    Text(list.kind.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(list.memberCount ?? 0)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel("Open list \(list.name)")
                    }
                }
                .padding(.vertical, 4)
            }

            if !workspaceStore.recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Profile Lookups")
                        .font(.subheadline.weight(.semibold))

                    ForEach(workspaceStore.recentSearches.prefix(3)) { search in
                        Button {
                            workspaceStore.lastProfileQuery = search.query
                            workspaceStore.selectedTab = .profile
                        } label: {
                            HStack {
                                Text(search.query)
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                                    .foregroundStyle(Color.skyPrimary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            if !workspaceStore.operationLog.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Bulk Actions")
                        .font(.subheadline.weight(.semibold))

                    ForEach(workspaceStore.operationLog.prefix(3)) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                            Text(entry.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if let primaryList = largestLists.first {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quick Start")
                        .font(.subheadline.weight(.semibold))

                    NavigationLink {
                        ListDetailView(list: primaryList) { updatedList in
                            viewModel.updateList(updatedList)
                        }
                    } label: {
                        Label("Open Import and Compare Tools", systemImage: "wand.and.stars")
                    }

                    Button {
                        workspaceStore.selectedTab = .profile
                    } label: {
                        Label("Open Profile Inspector", systemImage: "person.text.rectangle")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var recentListChanges: [ListMembershipSnapshotSummary] {
        allLists.compactMap { list in
            let history = workspaceStore.snapshotHistory(for: list.id)
            guard history.count >= 2,
                  let newer = history.first,
                  let older = history.dropFirst().first else {
                return nil
            }

            return workspaceStore.compareSnapshots(
                listID: list.id,
                newerSnapshotID: newer.id,
                olderSnapshotID: older.id
            )
        }
        .filter(\.hasChanges)
        .sorted { $0.currentCaptureDate > $1.currentCaptureDate }
        .prefix(3)
        .map { $0 }
    }

    private func changeSummary(for summary: ListMembershipSnapshotSummary) -> String {
        "\(summary.addedMembers.count) added, \(summary.removedMembers.count) removed at \(summary.currentCaptureDate.formatted(date: .omitted, time: .shortened))"
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
