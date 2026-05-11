import SwiftUI

struct iPadAccountSwitcher: View {
    @Binding var isPresented: Bool

    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient

    @State private var isShowingAccountManagement = false
    @State private var isShowingAddAccount = false
    @State private var editingLabelAccount: AppAccount?
    @State private var editLabelText = ""
    @ScaledMetric private var avatarSize = 44.0

    var body: some View {
        NavigationStack {
            List {
                if accountStore.accounts.isEmpty {
                    Section {
                        ContentUnavailableView(
                            loc("account.no_accounts.title"),
                            systemImage: "person.crop.circle.badge.plus",
                            description: Text(loc("account.no_accounts.desc"))
                        )
                    }
                } else {
                    Section {
                        ForEach(accountStore.accounts) { account in
                            Button {
                                switchToAccount(account)
                            } label: {
                                accountRow(account)
                            }
                            .buttonStyle(.plain)
                            .disabled(account.id == accountStore.activeAccountID)
                            .contextMenu {
                                Button(role: .destructive) {
                                    accountStore.removeAccount(account, client: blueskyClient)
                                } label: {
                                    Label(loc("account.remove"), systemImage: "trash")
                                }

                                Button {
                                    editLabelText = account.label ?? ""
                                    editingLabelAccount = account
                                } label: {
                                    Label(loc("account.edit_label"), systemImage: "tag")
                                }
                            }
                        }
                        .onMove(perform: accountStore.moveAccount)
                        .onDelete { indexSet in
                            for index in indexSet {
                                let account = accountStore.accounts[index]
                                accountStore.removeAccount(account, client: blueskyClient)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        isShowingAccountManagement = true
                    } label: {
                        Label(loc("account.switcher.manage"), systemImage: "slider.horizontal.3")
                            .font(.body)
                    }
                    .accessibilityHint("Opens full account management")

                    Button {
                        isShowingAddAccount = true
                    } label: {
                        Label(loc("account.manage.add"), systemImage: "plus")
                            .font(.body)
                    }
                    .accessibilityHint("Add a new Bluesky account")
                }
            }
            .navigationTitle(loc("account.switch"))
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, .constant(.active))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("actions.done")) {
                        isPresented = false
                    }
                }
            }
            .alert(loc("account.manage.title"), isPresented: .constant(accountStore.errorMessage != nil), actions: {
                Button(loc("actions.ok")) {
                    accountStore.errorMessage = nil
                }
            }, message: {
                Text(accountStore.errorMessage ?? "")
            })
            .sheet(item: $editingLabelAccount) { account in
                NavigationStack {
                    List {
                        Section(loc("account.edit_label.section")) {
                            TextField(loc("account.edit_label.placeholder"), text: $editLabelText)
                                .textInputAutocapitalization(.never)
                            Button(loc("account.edit_label.clear"), role: .destructive) {
                                accountStore.setLabel(for: account, label: nil)
                                editingLabelAccount = nil
                            }
                        }
                        Section(loc("account.edit_label.suggestions")) {
                            ForEach(["Work", "Personal", "Community", "Testing"], id: \.self) { option in
                                Button {
                                    editLabelText = option
                                } label: {
                                    HStack {
                                        Text(loc("account.edit_label.\(option.lowercased())")).foregroundStyle(.primary)
                                        if editLabelText == option { Spacer(); Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle(loc("account.edit_label.title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(loc("account.edit_label.save")) {
                                accountStore.setLabel(for: account, label: editLabelText)
                                editingLabelAccount = nil
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button(loc("account.edit_label.cancel")) { editingLabelAccount = nil }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $isShowingAccountManagement) {
                AccountSwitcherSheet(isPresented: $isShowingAccountManagement)
                    .environmentObject(accountStore)
                    .environmentObject(blueskyClient)
            }
            .sheet(isPresented: $isShowingAddAccount) {
                AddAccountView()
                    .environmentObject(accountStore)
                    .environmentObject(blueskyClient)
            }
        }
        .frame(idealWidth: 400)
        .presentationCompactAdaptation(.popover)
    }

    private func switchToAccount(_ account: AppAccount) {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        accountStore.setActiveAccount(account)
        generator.selectionChanged()
        isPresented = false
    }

    private func accountRow(_ account: AppAccount) -> some View {
        HStack(spacing: 14) {
            avatarView(for: account)

            VStack(alignment: .leading, spacing: 3) {
                Text(account.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text(account.handle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let label = account.label {
                        Text(label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.skyPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.skyPrimary.opacity(0.1), in: Capsule())
                    }
                }
            }

            Spacer(minLength: 12)

            if account.id == accountStore.activeAccountID {
                Text(loc("account.active"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.skyPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.skyPrimary.opacity(0.12), in: Capsule())
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func avatarView(for account: AppAccount) -> some View {
        if let avatarURL = account.avatarURL {
            AsyncImage(url: avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                avatarPlaceholder(account)
            }
            .frame(width: avatarSize, height: avatarSize)
            .clipShape(Circle())
            .overlay {
                Circle().stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
        } else {
            avatarPlaceholder(account)
        }
    }

    private func avatarPlaceholder(_ account: AppAccount) -> some View {
        Circle()
            .fill(account.id == accountStore.activeAccountID ? Color.skyPrimary : Color.gray.opacity(0.25))
            .frame(width: avatarSize, height: avatarSize)
            .overlay {
                Text(account.displayName.prefix(1).uppercased())
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }
    }
}

#Preview {
    iPadAccountSwitcher(isPresented: .constant(true))
        .environmentObject(AccountStore(preview: true))
        .environmentObject(PreviewBlueskyClient())
}
