import SwiftUI

struct RootView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @EnvironmentObject private var workspaceStore: ModerationWorkspaceStore
    @EnvironmentObject private var localizationManager: LocalizationManager
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        TabView(selection: $workspaceStore.selectedTab) {
            ListsView()
                .tag(WorkspaceTab.moderation)
                .tabItem {
                    Label {
                        Text(localizationManager.localized("tab.moderation"))
                    } icon: {
                        Image(systemName: "checklist.checked")
                    }
                }

            SettingsView()
                .tag(WorkspaceTab.settings)
                .tabItem {
                    Label {
                        Text(localizationManager.localized("tab.settings"))
                    } icon: {
                        Image(systemName: "gearshape")
                    }
                }

            InfoView()
                .tag(WorkspaceTab.info)
                .tabItem {
                    Label {
                        Text(localizationManager.localized("tab.info"))
                    } icon: {
                        Image(systemName: "sparkles.rectangle.stack")
                    }
                }

            AccountTabView()
                .tag(WorkspaceTab.account)
                .tabItem {
                    Label {
                        Text(localizationManager.localized("tab.accounts"))
                    } icon: {
                        Image(systemName: "person.circle")
                    }
                }
        }
        .tint(.skyPrimary)
        .sheet(isPresented: .init(get: { !hasSeenOnboarding }, set: { hasSeenOnboarding = !$0 })) {
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
                            Text(verbatim: localizationManager.localized("onboarding.title"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Text(verbatim: localizationManager.localized("onboarding.subtitle"))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.top, 32)

                        VStack(alignment: .leading, spacing: 16) {
                            OnboardingRow(icon: "checklist.checked", color: .skyPrimary, title: localizationManager.localized("tab.moderation"), description: localizationManager.localized("onboarding.moderation.desc"))
                            OnboardingRow(icon: "person.text.rectangle", color: .skyAccent, title: localizationManager.localized("tab.profile"), description: localizationManager.localized("onboarding.profile.desc"))
                            OnboardingRow(icon: "gearshape", color: .orange, title: localizationManager.localized("tab.settings"), description: localizationManager.localized("onboarding.settings.desc"))
                            OnboardingRow(icon: "sparkles.rectangle.stack", color: .purple, title: localizationManager.localized("tab.info"), description: localizationManager.localized("onboarding.info.desc"))
                        }

                        Button {
                            hasSeenOnboarding = true
                        } label: {
                            Text(verbatim: localizationManager.localized("onboarding.get_started"))
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .glassProminentButton()
                        .padding(.horizontal)
                    }
                    .padding()
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(localizationManager.localized("onboarding.close")) {
                            hasSeenOnboarding = true
                        }
                        .accessibilityLabel("Close onboarding")
                    }
                }
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
