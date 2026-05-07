import SwiftUI

struct AccountListView: View {
    @Bindable var viewModel: AccountViewModel
    @State private var showAddAccount = false
    @State private var accountToDelete: BlueskyAccount?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.accounts.isEmpty {
                    EmptyStateView(
                        icon: "person.crop.circle.badge.plus",
                        title: "No Accounts",
                        message: "Add your first Bluesky account to get started managing your lists.",
                        actionTitle: "Add Account",
                        action: { showAddAccount = true }
                    )
                } else {
                    accountList
                }
            }
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !viewModel.accounts.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showAddAccount = true }) {
                            Label("Add Account", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddAccount) {
                AddAccountView(viewModel: viewModel)
            }
            .alert("Remove Account?", isPresented: $showDeleteConfirmation, presenting: accountToDelete) { account in
                Button("Remove", role: .destructive) {
                    viewModel.removeAccount(account)
                }
                Button("Cancel", role: .cancel) {}
            } message: { account in
                Text("This will remove @\(account.handle) and delete all stored credentials.")
            }
        }
    }

    private var accountList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.accounts) { account in
                    AccountRow(
                        account: account,
                        isActive: account.id == viewModel.activeSession?.accountId,
                        onTap: {
                            if account.id != viewModel.activeSession?.accountId {
                                Task {
                                    await viewModel.switchAccount(to: account)
                                }
                            }
                        },
                        onDelete: {
                            accountToDelete = account
                            showDeleteConfirmation = true
                        }
                    )

                    if account.id != viewModel.accounts.last?.id {
                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Add Account Button at bottom
            Button(action: { showAddAccount = true }) {
                Label("Add Another Account", systemImage: "plus.circle.fill")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
                    .tint(.accentColor)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer(minLength: 40)
        }
    }
}

// MARK: - Account Row Cell

private struct AccountRow: View {
    let account: BlueskyAccount
    let isActive: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.accentColor.opacity(0.15) : Color(.systemGray5))
                        .frame(width: 44, height: 44)

                    Text(String(account.handle.prefix(1).uppercased()))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isActive ? .accent : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(account.handle)")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let did = account.did {
                        Text(did)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.accent)
                        .symbolRenderingMode(.hierarchical)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Remove", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Account @\(account.handle)\(isActive ? ", active" : "")")
        .accessibilityHint(isActive ? "Currently selected" : "Double tap to switch to this account")
    }
}

#Preview {
    let vm = AccountViewModel()
    vm.accounts = [
        BlueskyAccount(handle: "alice.bsky.social", did: "did:plc:abc123", isActive: true),
        BlueskyAccount(handle: "bob.bsky.social", did: "did:plc:def456")
    ]
    return AccountListView(viewModel: vm)
}
