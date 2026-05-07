import SwiftUI

struct AccountsView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @State private var isPresentingAddAccount = false

    var body: some View {
        NavigationStack {
            List {
                if accountStore.accounts.isEmpty {
                    ContentUnavailableView(
                        "No Accounts",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Add your first Bluesky account to begin.")
                    )
                } else {
                    Section("Saved Accounts") {
                        ForEach(accountStore.accounts) { account in
                            AccountRowView(
                                account: account,
                                isActive: account.id == accountStore.activeAccountID
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    accountStore.removeAccount(account)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    accountStore.setActiveAccount(account)
                                } label: {
                                    Label("Set Active", systemImage: "checkmark.circle")
                                }
                                .tint(.skyPrimary)
                            }
                        }
                    }
                }

                Section("Security") {
                    Label("App passwords are stored in the Keychain.", systemImage: "lock.shield")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingAddAccount = true
                    } label: {
                        Label("Add Account", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddAccount) {
                AddAccountView()
                    .environmentObject(accountStore)
                    .environmentObject(blueskyClient)
            }
            .task {
                await accountStore.refreshAccountProfiles(using: blueskyClient)
            }
            .alert("Accounts", isPresented: .constant(accountStore.errorMessage != nil), actions: {
                Button("OK") {
                    accountStore.errorMessage = nil
                }
            }, message: {
                Text(accountStore.errorMessage ?? "")
            })
        }
    }
}

#Preview {
    AccountsView()
        .environmentObject(AccountStore(preview: true))
        .environmentObject(PreviewBlueskyClient())
}
