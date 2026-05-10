import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @AppStorage("debugMode") private var debugMode = false
    @State private var isShowingClearCacheConfirmation = false
    @State private var cacheStatusMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Preferences") {
                    Toggle(isOn: $debugMode) {
                        Label("Debug", systemImage: "wrench.adjustable")
                    }

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
