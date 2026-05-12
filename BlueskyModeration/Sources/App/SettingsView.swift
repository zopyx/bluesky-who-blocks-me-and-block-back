import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var appLockManager: AppLockManager
    @AppStorage("debugMode") private var debugMode = false
    @State private var isShowingClearCacheConfirmation = false
    @State private var cacheStatusMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
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

                if appLockManager.isBiometricsAvailable {
                    Section {
                        Toggle(isOn: $appLockManager.isEnabled) {
                            Label {
                                Text(loc("settings.biometric_lock").replacingOccurrences(of: "{biometric}", with: appLockManager.biometricLabel))
                            } icon: {
                                Image(systemName: biometricIcon)
                            }
                        }

                        if appLockManager.isEnabled {
                            Picker(loc("settings.auto_lock"), selection: $appLockManager.timeoutMinutes) {
                                Text(loc("settings.auto_lock.immediately")).tag(0)
                                Text(loc("settings.auto_lock.1min")).tag(1)
                                Text(loc("settings.auto_lock.5min")).tag(5)
                                Text(loc("settings.auto_lock.15min")).tag(15)
                                Text(loc("settings.auto_lock.30min")).tag(30)
                            }
                        }
                    } header: {
                        Text(loc("settings.security"))
                    } footer: {
                        if appLockManager.isEnabled {
                            Text(loc("settings.biometric_footer").replacingOccurrences(of: "{biometric}", with: appLockManager.biometricLabel))
                        }
                    }
                }

                Section {
                    Toggle(isOn: $debugMode) {
                        Label {
                            Text(localizationManager.localized("settings.debug"))
                        } icon: {
                            Image(systemName: "wrench.adjustable")
                        }
                    }
                    .accessibilityHint("Enables additional debugging tools and logging")
                } header: {
                    Text(localizationManager.localized("settings.internal"))
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
                    cacheStatusMessage = loc("settings.cache_cleared")
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
