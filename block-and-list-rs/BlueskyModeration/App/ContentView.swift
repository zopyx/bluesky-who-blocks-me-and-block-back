import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var accountViewModel = AccountViewModel()
    @State private var listViewModel = ListViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ListOverviewView(
                listViewModel: listViewModel,
                accountViewModel: accountViewModel
            )
            .tabItem {
                Label("Lists", systemImage: "list.bullet.rectangle.portrait")
            }
            .tag(0)

            AccountListView(viewModel: accountViewModel)
                .tabItem {
                    Label("Accounts", systemImage: "person.2")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .onAppear {
            accountViewModel.setModelContext(modelContext)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @State private var showPrivacyPolicy = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                            .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Secure Storage")
                                .font(.body.weight(.medium))
                            Text("Passwords and tokens stored in Keychain")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    HStack(spacing: 16) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("AT Protocol")
                                .font(.body.weight(.medium))
                            Text("Direct connection to Bluesky servers")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Security")
                }

                Section {
                    Link(destination: URL(string: "https://bsky.app/settings/app-passwords")!) {
                        Label("Manage App Passwords", systemImage: "key.fill")
                    }

                    Link(destination: URL(string: "https://bsky.app")!) {
                        Label("Open Bluesky", systemImage: "arrow.up.forward.square")
                    }
                } header: {
                    Text("Bluesky")
                }

                Section {
                    HStack {
                        Text("Version")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    ContentView()
}
