import SwiftUI

struct SettingsView: View {
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

                Section("Next") {
                    Text("Profile inspection, list workflows, and moderation tooling.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
