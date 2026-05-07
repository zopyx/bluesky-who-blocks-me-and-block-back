import SwiftUI

struct AccountRowView: View {
    let account: AppAccount
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isActive ? Color.skyPrimary : Color.gray.opacity(0.25))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(account.displayName.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(account.displayName)
                    .font(.headline)
                Text(account.handle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isActive {
                Text("Active")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.skyPrimary.opacity(0.14), in: Capsule())
                    .foregroundStyle(Color.skyPrimary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        AccountRowView(
            account: AppAccount(handle: "team-alpha.bsky.social", displayName: "Team Alpha"),
            isActive: true
        )
    }
}
