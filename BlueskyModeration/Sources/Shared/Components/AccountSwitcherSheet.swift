import SwiftUI

struct AccountSwitcherSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var accountStore: AccountStore

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
}
