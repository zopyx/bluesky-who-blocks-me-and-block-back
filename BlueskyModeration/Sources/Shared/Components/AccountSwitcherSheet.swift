import SwiftUI

struct AccountSwitcherSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient

    var body: some View {
        NavigationStack {
            List {
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
                }
            }
            .navigationTitle("Switch Account")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await accountStore.refreshAccountProfiles(using: blueskyClient)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    AccountSwitcherSheet(isPresented: .constant(true))
        .environmentObject(AccountStore(preview: true))
        .environmentObject(PreviewBlueskyClient())
}
