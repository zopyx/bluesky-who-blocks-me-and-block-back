import SwiftUI

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient

    @State private var handle = ""
    @State private var appPassword = ""
    @State private var showAdvanced = false
    @State private var customPDS = ""

    private var detectedPDS: String? {
        guard !handle.isEmpty else { return nil }
        let parts = handle.split(separator: "@").last?.split(separator: ".")
        guard let parts, parts.count >= 2 else { return nil }
        let domain = parts.suffix(2).joined(separator: ".")
        guard domain != "bsky.social" else { return nil }
        return "https://\(domain)"
    }

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

                if let detectedPDS {
                    Section {
                        LabeledContent("Detected PDS", value: detectedPDS)
                            .foregroundStyle(.secondary)
                    }
                }

                DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                    TextField("PDS Entryway (optional)", text: $customPDS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .placeholder(when: customPDS.isEmpty) {
                            Text("e.g. https://eurosky.social")
                                .foregroundStyle(.tertiary)
                        }
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
                            let entrywayURL = URL(string: customPDS.trimmingCharacters(in: .whitespacesAndNewlines))
                                ?? (detectedPDS.flatMap(URL.init))
                            let added = await accountStore.addAccount(
                                handle: handle,
                                appPassword: appPassword,
                                entrywayURL: entrywayURL,
                                client: blueskyClient
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

extension View {
    func placeholder(when shouldShow: Bool, alignment: Alignment = .leading, @ViewBuilder placeholder: () -> some View) -> some View {
        overlay(alignment: alignment) {
            if shouldShow { placeholder().allowsHitTesting(false) }
        }
    }
}

#Preview {
    AddAccountView()
        .environmentObject(AccountStore(preview: true))
        .environmentObject(PreviewBlueskyClient())
}
