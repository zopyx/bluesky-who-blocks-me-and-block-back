import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @State private var isShowingClearCacheConfirmation = false
    @State private var cacheStatusMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Accounts") {
                    NavigationLink {
                        AccountsView()
                    } label: {
                        Label("Manage Accounts", systemImage: "person.2")
                    }
                }

                Section("Status") {
                    LabeledContent("Build Stage", value: "Prototype")
                    LabeledContent("Data Source", value: "Live Bluesky API")
                }

                Section("Preferences") {
                    Button(role: .destructive) {
                        isShowingClearCacheConfirmation = true
                    } label: {
                        Label("Clear Cache", systemImage: "trash")
                    }

                    if let cacheStatusMessage {
                        Text(cacheStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Next") {
                    Text("Profile inspection, list workflows, and moderation tooling.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Clear cached network and image data?",
                isPresented: $isShowingClearCacheConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Cache", role: .destructive) {
                    blueskyClient.clearCache()
                    cacheStatusMessage = "Local cache cleared."
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Saved accounts and app passwords will not be removed.")
            }
        }
    }
}

#Preview {
    SettingsView()
}
