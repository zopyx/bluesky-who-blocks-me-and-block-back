import SwiftUI

struct AccountChip: View {
    let account: AppAccount

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.skyPrimary)
                .frame(width: 22, height: 22)
                .overlay {
                    Text(account.displayName.prefix(1).uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }

            Text(account.displayName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }
}

#Preview {
    AccountChip(account: AppAccount(handle: "team-alpha.bsky.social", displayName: "Team Alpha"))
}
