import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject private var appLockManager: AppLockManager

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(Color.skyPrimary)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if appLockManager.isAuthenticating {
                ProgressView()
                    .padding(.top, 8)
            } else {
                Button {
                    Task { await appLockManager.authenticate() }
                } label: {
                    Label("Unlock", systemImage: icon)
                        .font(.headline)
                        .frame(maxWidth: 200)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var icon: String {
        switch appLockManager.biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.shield"
        }
    }

    private var title: String {
        switch appLockManager.biometricType {
        case .faceID: return "Use Face ID to Unlock"
        case .touchID: return "Use Touch ID to Unlock"
        default: return "App Locked"
        }
    }

    private var subtitle: String {
        if appLockManager.isBiometricsAvailable {
            return "Authenticate with \(appLockManager.biometricLabel) to access your accounts and moderation data."
        } else {
            return "Biometric authentication is not available on this device."
        }
    }
}
