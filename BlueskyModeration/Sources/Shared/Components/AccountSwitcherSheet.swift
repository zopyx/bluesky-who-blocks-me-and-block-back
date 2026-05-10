import SwiftUI

struct AccountSwitcherSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @State private var isPresentingAddAccount = false
    @State private var editingLabelAccount: AppAccount?
    @State private var editLabelText = ""

    private let labelOptions = ["Work", "Personal", "Community", "Testing", nil] as [String?]

    var body: some View {
        NavigationStack {
            List {
                Group {
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
                            .contextMenu {
                                Button(role: .destructive) {
                                    accountStore.removeAccount(account, client: blueskyClient)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                Button {
                                    editLabelText = account.label ?? ""
                                    editingLabelAccount = account
                                } label: {
                                    Label("Edit Label", systemImage: "tag")
                                }
                            }
                        }
                    }
                    }
                }

                .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await accountStore.refreshAccountProfiles(using: blueskyClient)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
            .sheet(item: $editingLabelAccount) { account in
                NavigationStack {
                    List {
                        Section("Label") {
                            TextField("e.g. Work, Personal", text: $editLabelText)
                                .textInputAutocapitalization(.never)
                            Button("Clear Label", role: .destructive) {
                                accountStore.setLabel(for: account, label: nil)
                                editingLabelAccount = nil
                            }
                        }
                        Section("Suggestions") {
                            ForEach(["Work", "Personal", "Community", "Testing"], id: \.self) { option in
                                Button {
                                    editLabelText = option
                                } label: {
                                    HStack {
                                        Text(option).foregroundStyle(.primary)
                                        if editLabelText == option { Spacer(); Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("Edit Label")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                accountStore.setLabel(for: account, label: editLabelText)
                                editingLabelAccount = nil
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { editingLabelAccount = nil }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    AccountSwitcherSheet(isPresented: .constant(true))
        .environmentObject(AccountStore(preview: true))
        .environmentObject(PreviewBlueskyClient())
}
