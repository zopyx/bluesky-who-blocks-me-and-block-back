import SwiftUI

struct ListOverviewView: View {
    @Bindable var listViewModel: ListViewModel
    @Bindable var accountViewModel: AccountViewModel

    @State private var selectedFilter: ListFilter = .all
    @State private var showAccountPicker = false
    @State private var showAddAccount = false

    enum ListFilter: String, CaseIterable {
        case all = "All"
        case curation = "Curation"
        case moderation = "Moderation"
    }

    private var displayedLists: [BlueskyList] {
        switch selectedFilter {
        case .all:
            return listViewModel.filteredLists
        case .curation:
            return listViewModel.filteredLists.filter { $0.purpose == .curation }
        case .moderation:
            return listViewModel.filteredLists.filter { $0.purpose == .moderation }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                content
            }
            .navigationTitle("Lists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AccountSwitcherButton(
                        accountViewModel: accountViewModel,
                        action: { showAccountPicker = true }
                    )
                }
            }
            .searchable(
                text: $listViewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search lists"
            )
            .refreshable {
                await refreshLists()
            }
            .sheet(isPresented: $showAccountPicker) {
                AccountPickerSheet(
                    accountViewModel: accountViewModel,
                    onSelect: { account in
                        Task {
                            await accountViewModel.switchAccount(to: account)
                        }
                    },
                    onAddAccount: {
                        showAddAccount = true
                    }
                )
            }
            .sheet(isPresented: $showAddAccount) {
                AddAccountView(viewModel: accountViewModel)
            }
            .task {
                await refreshLists()
            }
            .onChange(of: accountViewModel.activeSession) { _, _ in
                Task {
                    await refreshLists()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if accountViewModel.activeSession == nil {
            EmptyStateView(
                icon: "list.bullet.rectangle.portrait",
                title: "No Active Account",
                message: "Add a Bluesky account to view your lists.",
                actionTitle: "Add Account",
                action: { showAccountPicker = true }
            )
        } else if listViewModel.isLoading && listViewModel.lists.isEmpty {
            LoadingStateView(message: "Loading lists...")
        } else if listViewModel.lists.isEmpty && !listViewModel.isLoading {
            EmptyStateView(
                icon: "list.bullet.rectangle",
                title: "No Lists",
                message: "You don't have any lists yet. Lists you create or subscribe to on Bluesky will appear here."
            )
        } else {
            listContent
        }
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Filter Picker
                Section {
                    ForEach(displayedLists) { list in
                        NavigationLink(value: list) {
                            ListRowView(list: list)
                        }
                        .buttonStyle(.plain)

                        if list.id != displayedLists.last?.id {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                } header: {
                    filterHeader
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Stats footer
            if !listViewModel.lists.isEmpty {
                HStack(spacing: 16) {
                    StatBadge(
                        count: listViewModel.curationLists.count,
                        label: "Curation",
                        icon: "list.star",
                        color: .blue
                    )
                    StatBadge(
                        count: listViewModel.moderationLists.count,
                        label: "Moderation",
                        icon: "shield.lefthalf.filled",
                        color: .orange
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }

            Spacer(minLength: 40)
        }
        .navigationDestination(for: BlueskyList.self) { list in
            ListDetailView(list: list, accountSession: accountViewModel.activeSession)
        }
    }

    private var filterHeader: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(ListFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func refreshLists() async {
        guard let session = accountViewModel.activeSession else {
            listViewModel.clear()
            return
        }
        await listViewModel.fetchLists(for: session)
    }
}

// MARK: - Account Switcher Button

private struct AccountSwitcherButton: View {
    let accountViewModel: AccountViewModel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let session = accountViewModel.activeSession {
                    Text("@\(session.handle)")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                } else {
                    Label("Account", systemImage: "person.crop.circle")
                }

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let count: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(count)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Account Picker Sheet

struct AccountPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var accountViewModel: AccountViewModel
    let onSelect: (BlueskyAccount) -> Void
    let onAddAccount: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Active Account") {
                    if let active = accountViewModel.accounts.first(where: \.isActive) {
                        AccountRowView(account: active, isActive: true)
                    }
                }

                if accountViewModel.accounts.count > 1 {
                    Section("Switch To") {
                        ForEach(accountViewModel.accounts.filter { !$0.isActive }) { account in
                            Button {
                                onSelect(account)
                                dismiss()
                            } label: {
                                AccountRowView(account: account, isActive: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    Button {
                        dismiss()
                        onAddAccount()
                    } label: {
                        Label("Add New Account", systemImage: "plus.circle.fill")
                            .foregroundStyle(.accent)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Switch Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let accountVM = AccountViewModel()
    accountVM.accounts = [
        BlueskyAccount(handle: "alice.bsky.social", did: "did:plc:abc", isActive: true)
    ]
    accountVM.activeSession = AccountSession(
        accountId: UUID(),
        accessJwt: "test",
        did: "did:plc:abc",
        handle: "alice.bsky.social",
        pdsEndpoint: "https://bsky.social"
    )

    let listVM = ListViewModel()
    listVM.lists = [
        BlueskyList(
            uri: "at://did:plc:abc/app.bsky.graph.list/1",
            cid: "a",
            name: "Tech Twitter Refugees",
            description: "Developers and tech folks who moved to Bluesky",
            purpose: .curation,
            creatorHandle: "alice.bsky.social",
            creatorDid: "did:plc:abc",
            indexedAt: Date()
        ),
        BlueskyList(
            uri: "at://did:plc:abc/app.bsky.graph.list/2",
            cid: "b",
            name: "Spam Accounts",
            description: "Known spam and bot accounts",
            purpose: .moderation,
            creatorHandle: "alice.bsky.social",
            creatorDid: "did:plc:abc",
            indexedAt: Date()
        )
    ]

    return ListOverviewView(listViewModel: listVM, accountViewModel: accountVM)
}
