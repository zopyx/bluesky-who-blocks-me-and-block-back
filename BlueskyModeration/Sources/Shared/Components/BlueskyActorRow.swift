import SwiftUI

struct BlueskyActorRow: View {
    let actor: BlueskyActor

    var body: some View {
        HStack(spacing: 12) {
            avatarView

            VStack(alignment: .leading, spacing: 4) {
                Text(actor.title)
                    .font(.headline)
                Text(actor.handle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var avatarView: some View {
        if let avatarURL = actor.avatarURL {
            AsyncImage(url: avatarURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                avatarPlaceholder
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.skyPrimary.opacity(0.16))
            .frame(width: 40, height: 40)
            .overlay {
                Text(actor.title.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundStyle(Color.skyPrimary)
            }
    }
}

#Preview {
    List {
        BlueskyActorRow(
            actor: BlueskyActor(did: "did:plc:demo", handle: "alice.bsky.social", displayName: "Alice Chen")
        )
    }
}
