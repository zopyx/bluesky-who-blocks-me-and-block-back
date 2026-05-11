import SwiftUI

struct RootView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @EnvironmentObject private var workspaceStore: ModerationWorkspaceStore
    @EnvironmentObject private var localizationManager: LocalizationManager
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var isShowingQuickAccountSwitcher = false
    @State private var isShowingAccountManagement = false

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

            ProfileInspectorView()
                .tag(WorkspaceTab.profile)
                .tabItem {
                    Label {
                        Text(localizationManager.localized("tab.profile"))
                    } icon: {
                        Image(systemName: "person.text.rectangle")
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
        }
        .tint(.skyPrimary)
        .overlay(alignment: .topLeading) {
            if let activeAccount = accountStore.activeAccount {
                Button {
                    isShowingQuickAccountSwitcher = true
                } label: {
                    HStack(spacing: 8) {
                        accountAvatarView(for: activeAccount)

                        Text(activeAccount.displayName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .foregroundStyle(.primary)

                        Image(systemName: "chevron.up")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizationManager.localized("account.switcher.label"))
                .accessibilityHint(localizationManager.localized("account.switcher.hint"))
                .padding(.leading, 16)
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $isShowingQuickAccountSwitcher) {
            AccountQuickSwitcherSheet(
                isPresented: $isShowingQuickAccountSwitcher,
                onManageAccounts: openAccountManagement
            )
            .environmentObject(accountStore)
        }
        .sheet(isPresented: $isShowingAccountManagement) {
            AccountSwitcherSheet(isPresented: $isShowingAccountManagement)
                .environmentObject(accountStore)
                .environmentObject(blueskyClient)
        }
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

    @MainActor
    private func openAccountManagement() {
        isShowingQuickAccountSwitcher = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isShowingAccountManagement = true
        }
    }

    @ViewBuilder
    private func accountAvatarView(for account: AppAccount) -> some View {
        let avatarSize: CGFloat = 28
        if let avatarURL = account.avatarURL {
            AsyncImage(url: avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color.skyPrimary)
                    .overlay { Text(account.displayName.prefix(1).uppercased()).font(.caption.weight(.bold)).foregroundStyle(.white) }
            }
            .frame(width: avatarSize, height: avatarSize)
            .clipShape(Circle())
        } else {
            Circle().fill(Color.skyPrimary).frame(width: avatarSize, height: avatarSize)
                .overlay { Text(account.displayName.prefix(1).uppercased()).font(.caption.weight(.bold)).foregroundStyle(.white) }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AccountStore(preview: true))
        .environmentObject(PreviewBlueskyClient())
        .environmentObject(ModerationWorkspaceStore(preview: true))
}
