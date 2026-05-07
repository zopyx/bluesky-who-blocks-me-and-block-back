import SwiftUI

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient

    @State private var handle = ""
    @State private var appPassword = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Credentials") {
                    TextField("Handle", text: $handle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("App Password", text: $appPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Why app password?") {
                    Text("The app stores the password securely in the iOS Keychain and uses it for Bluesky account access.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let added = await accountStore.addAccount(
                                handle: handle,
                                appPassword: appPassword,
                                authenticator: blueskyClient
                            )
                            if added {
                                dismiss()
                            }
                        }
                    }
                    .disabled(
                        handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        appPassword.isEmpty ||
                        accountStore.isAddingAccount
                    )
                }
            }
            .overlay {
                if accountStore.isAddingAccount {
                    ZStack {
                        Color.black.opacity(0.08).ignoresSafeArea()
                        ProgressView("Validating Account")
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }
}

#Preview {
    AddAccountView()
        .environmentObject(AccountStore(preview: true))
        .environmentObject(PreviewBlueskyClient())
}
