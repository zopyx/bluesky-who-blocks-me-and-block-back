import SwiftUI
import UIKit

struct AccountQuickSwitcherSheet: View {
    @Binding var isPresented: Bool
    let onManageAccounts: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountStore: AccountStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(accountStore.accounts) { account in
                        Button {
                            switchAccount(to: account)
                        } label: {
                            AccountRowView(
                                account: account,
                                isActive: account.id == accountStore.activeAccountID
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(account.id == accountStore.activeAccountID)
                        .accessibilityHint("Switches to \(account.label ?? account.handle)")
                    }
                } header: {
                    Text(loc("account.switcher.accounts_section"))
                }

                Section {
                    Button {
                        isPresented = false
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(250))
                            onManageAccounts()
                        }
                    } label: {
                        Label(loc("account.switcher.manage"), systemImage: "slider.horizontal.3")
                    }
                    .accessibilityHint("Opens the full account management screen")
                }
            }
            .navigationTitle(loc("account.switcher.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(360), .medium])
        .presentationDragIndicator(.visible)
    }

    private func switchAccount(to account: AppAccount) {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        accountStore.setActiveAccount(account)
        generator.selectionChanged()
        dismiss()
    }
}

#Preview {
    AccountQuickSwitcherSheet(
        isPresented: .constant(true),
        onManageAccounts: {}
    )
    .environmentObject(AccountStore(preview: true))
}
