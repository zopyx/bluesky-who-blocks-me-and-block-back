import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var appLockManager: AppLockManager
    @EnvironmentObject private var iCloudSync: iCloudAccountSync
    @AppStorage("debugMode") private var debugMode = false
    @State private var isShowingClearCacheConfirmation = false
    @State private var cacheStatusMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $debugMode) {
                        Label {
                            Text(localizationManager.localized("settings.debug"))
                        } icon: {
                            Image(systemName: "wrench.adjustable")
                        }
                    }
                    .accessibilityHint("Enables additional debugging tools and logging")

                    Picker(selection: Binding(
                        get: { localizationManager.currentLanguage },
                        set: { localizationManager.currentLanguage = $0 }
                    )) {
                        ForEach(localizationManager.supportedLanguages, id: \.code) { lang in
                            HStack {
                                Text(lang.displayName)
                                Spacer()
                                Text(lang.code.uppercased())
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .tag(lang.code)
                        }
                    } label: {
                        Label {
                            Text(localizationManager.localized("settings.language"))
                        } icon: {
                            Image(systemName: "globe")
                        }
                    }
                    .accessibilityHint("Changes the display language for the entire app")

                    Button(role: .destructive) {
                        isShowingClearCacheConfirmation = true
                    } label: {
                        Label {
                            Text(localizationManager.localized("settings.clear_cache"))
                        } icon: {
                            Image(systemName: "trash")
                        }
                    }
                    .accessibilityHint("Removes cached network data and images from the device")

                    if let cacheStatusMessage {
                        Text(cacheStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(localizationManager.localized("settings.preferences"))
                }

                Section {
                    Toggle(isOn: $iCloudSync.isEnabled) {
                        Label {
                            Text("iCloud Sync")
                        } icon: {
                            Image(systemName: "icloud")
                        }
                    }
                } header: {
                    Text("iCloud")
                } footer: {
                    Text(iCloudSync.isEnabled ? "Account handles and labels sync across your devices. App passwords stay on each device for security." : "Enable to keep your account configuration consistent across devices.")
                }

                if appLockManager.isBiometricsAvailable {
                    Section {
                        Toggle(isOn: $appLockManager.isEnabled) {
                            Label {
                                Text("\(appLockManager.biometricLabel) Lock")
                            } icon: {
                                Image(systemName: biometricIcon)
                            }
                        }

                        if appLockManager.isEnabled {
                            Picker("Auto-Lock", selection: $appLockManager.timeoutMinutes) {
                                Text("Immediately").tag(0)
                                Text("1 minute").tag(1)
                                Text("5 minutes").tag(5)
                                Text("15 minutes").tag(15)
                                Text("30 minutes").tag(30)
                            }
                        }
                    } header: {
                        Text("Security")
                    } footer: {
                        if appLockManager.isEnabled {
                            Text("Lock the app with \(appLockManager.biometricLabel) when it goes to the background.")
                        }
                    }
                }
            }
            .navigationTitle(localizationManager.localized("settings.title"))
            .confirmationDialog(
                localizationManager.localized("settings.clear_cache.confirm"),
                isPresented: $isShowingClearCacheConfirmation,
                titleVisibility: .visible
            ) {
                Button(localizationManager.localized("settings.clear_cache"), role: .destructive) {
                    blueskyClient.clearCache()
                    cacheStatusMessage = "Local cache cleared."
                }
                Button(localizationManager.localized("settings.cancel"), role: .cancel) {}
            } message: {
                Text(localizationManager.localized("settings.clear_cache.message"))
            }
        }
    }

    private var biometricIcon: String {
        switch appLockManager.biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.shield"
        }
    }
}

#Preview {
    SettingsView()
}
