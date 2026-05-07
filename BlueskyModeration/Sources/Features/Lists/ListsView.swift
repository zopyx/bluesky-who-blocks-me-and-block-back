import SwiftUI

struct ListsView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @StateObject private var viewModel = ListsViewModel()
    @State private var isShowingAccountPicker = false

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
                                AccountSummaryCard(account: activeAccount)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                    .listRowBackground(Color.clear)
                            }
                        }

                        ForEach(BlueskyList.Kind.allCases, id: \.self) { kind in
                            if let lists = groupedLists[kind], !lists.isEmpty {
                                Section(kind.title) {
                                    ForEach(lists) { list in
                                        NavigationLink {
                                            ListDetailView(list: list)
                                        } label: {
                                            ListRowView(list: list)
                                        }
                                    }
                                }
                            }
                        }
                    }
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
                            AccountChip(account: activeAccount)
                        }
                        .buttonStyle(.plain)
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
                    .disabled(accountStore.activeAccount == nil)
                }
            }
            .sheet(isPresented: $isShowingAccountPicker) {
                AccountSwitcherSheet(isPresented: $isShowingAccountPicker)
                    .environmentObject(accountStore)
            }
            .task(id: accountStore.activeAccountID) {
                await reload()
            }
            .alert("Lists", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            }, message: {
                Text(viewModel.errorMessage ?? "")
            })
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
}

#Preview {
    ListsView()
        .environmentObject(AccountStore(preview: true))
        .environmentObject(PreviewBlueskyClient())
}
