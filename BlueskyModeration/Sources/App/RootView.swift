import SwiftUI

struct RootView: View {
    @EnvironmentObject private var workspaceStore: ModerationWorkspaceStore

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
    }
}

#Preview {
    RootView()
        .environmentObject(AccountStore(preview: true))
        .environmentObject(PreviewBlueskyClient())
        .environmentObject(ModerationWorkspaceStore(preview: true))
}
