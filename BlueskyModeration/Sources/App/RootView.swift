import SwiftUI

struct RootView: View {
    @EnvironmentObject private var workspaceStore: ModerationWorkspaceStore
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        TabView(selection: $workspaceStore.selectedTab) {
            ListsView()
                .tag(WorkspaceTab.moderation)
                .tabItem {
                    Label("Moderation", systemImage: "checklist.checked")
                }

            ProfileInspectorView()
                .tag(WorkspaceTab.profile)
                .tabItem {
                    Label("Profile", systemImage: "person.text.rectangle")
                }

            SettingsView()
                .tag(WorkspaceTab.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }

            InfoView()
                .tag(WorkspaceTab.info)
                .tabItem {
                    Label("Info", systemImage: "sparkles.rectangle.stack")
                }
        }
        .tint(.skyPrimary)
        .sheet(isPresented: .init(get: { !hasSeenOnboarding }, set: { _ in })) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Image(systemName: "checklist.checked")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.skyPrimary)
                    Image("RulyxLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 36)
                            Text("Bluesky moderation made easy")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Text("Free  ·  Open source  ·  No ads  ·  No tracking")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.top, 32)

                        VStack(alignment: .leading, spacing: 16) {
                            OnboardingRow(icon: "checklist.checked", color: .skyPrimary, title: "Moderation", description: "Browse lists, search for actors, import or export members, and compare lists.")
                            OnboardingRow(icon: "person.text.rectangle", color: .skyAccent, title: "Profile", description: "Inspect profiles, view labels and stats, and perform moderation actions.")
                            OnboardingRow(icon: "gearshape", color: .orange, title: "Settings", description: "Manage accounts, clear cache, and review data classification.")
                            OnboardingRow(icon: "sparkles.rectangle.stack", color: .purple, title: "Info", description: "Learn about the app, review workflows, and access privacy information.")
                        }

                        Button {
                            hasSeenOnboarding = true
                        } label: {
                            Text("Get Started")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)
                    }
                    .padding()
                }
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AccountStore(preview: true))
        .environmentObject(PreviewBlueskyClient())
        .environmentObject(ModerationWorkspaceStore(preview: true))
}
