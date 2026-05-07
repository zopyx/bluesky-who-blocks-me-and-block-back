import SwiftUI

struct AccountChip: View {
    let account: AppAccount
    let avatarURL: URL?

    var body: some View {
        HStack(spacing: 8) {
            avatarView

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

    @ViewBuilder
    private var avatarView: some View {
        if let avatarURL = avatarURL ?? account.avatarURL {
            AsyncImage(url: avatarURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                avatarPlaceholder
            }
            .frame(width: 22, height: 22)
            .clipShape(Circle())
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.skyPrimary)
            .frame(width: 22, height: 22)
            .overlay {
                Text(account.displayName.prefix(1).uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
    }
}

#Preview {
    AccountChip(
        account: AppAccount(handle: "team-alpha.bsky.social", displayName: "Team Alpha"),
        avatarURL: nil
    )
}
