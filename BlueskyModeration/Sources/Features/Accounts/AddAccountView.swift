import SwiftUI

enum ProviderOption: String, CaseIterable, Identifiable {
    case bluesky = "Bluesky"
    case eurosky = "Eurosky"
    case other = "Other"

    var id: String { rawValue }

    var entrywayURL: URL {
        switch self {
        case .bluesky: return URL(string: "https://bsky.social")!
        case .eurosky: return URL(string: "https://eurosky.social")!
        case .other: return URL(string: "https://bsky.social")!
        }
    }
}

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient

    @State private var handle = ""
    @State private var appPassword = ""
    @State private var selectedProvider: ProviderOption = .bluesky
    @State private var customPDS = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Provider") {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(ProviderOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }

                    if selectedProvider == .other {
                        TextField("Custom PDS URL", text: $customPDS)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                }

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
                            let entrywayURL: URL?
                            if selectedProvider == .other && !customPDS.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                entrywayURL = URL(string: customPDS.trimmingCharacters(in: .whitespacesAndNewlines))
                            } else {
                                entrywayURL = selectedProvider.entrywayURL
                            }
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

#Preview {
    AddAccountView()
        .environmentObject(AccountStore(preview: true))
        .environmentObject(PreviewBlueskyClient())
}
