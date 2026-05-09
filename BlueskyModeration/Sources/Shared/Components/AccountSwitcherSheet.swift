import SwiftUI

struct AccountSwitcherSheet: View {
    @Binding var isPresented: Bool
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
                            Button {
                                accountStore.setActiveAccount(account)
                                isPresented = false
                            } label: {
                                AccountRowView(
                                    account: account,
                                    isActive: account.id == accountStore.activeAccountID
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    accountStore.removeAccount(account, client: blueskyClient)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .accessibilityHint("This action cannot be undone.")
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    accountStore.setActiveAccount(account)
                                    isPresented = false
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
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await accountStore.refreshAccountProfiles(using: blueskyClient)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPresentingAddAccount = true
                    } label: {
                        Label("Add Account", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddAccount) {
                AddAccountView()
                    .environmentObject(accountStore)
                    .environmentObject(blueskyClient)
            }
            .alert("Accounts", isPresented: .constant(accountStore.errorMessage != nil), actions: {
                Button("OK") {
                    accountStore.errorMessage = nil
                }
            }, message: {
                Text(accountStore.errorMessage ?? "")
            })
        }
        .presentationDetents([.large])
    }
}

#Preview {
    AccountSwitcherSheet(isPresented: .constant(true))
        .environmentObject(AccountStore(preview: true))
        .environmentObject(PreviewBlueskyClient())
}
