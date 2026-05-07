import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            ListsView()
                .tabItem {
                    Label("Lists", systemImage: "list.bullet.rectangle")
                }

            ProfileInspectorView()
                .tabItem {
                    Label("Profile", systemImage: "person.text.rectangle")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }

            InfoView()
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
}
