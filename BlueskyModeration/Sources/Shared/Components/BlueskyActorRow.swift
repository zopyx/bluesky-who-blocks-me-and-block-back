import SwiftUI

struct BlueskyActorRow: View {
    let actor: BlueskyActor

    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 40

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
        .padding(.vertical, 10)
        .accessibilityLabel(loc("actor_row.label").replacingOccurrences(of: "{title}", with: actor.title).replacingOccurrences(of: "{handle}", with: actor.handle))
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
            .frame(width: avatarSize, height: avatarSize)
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
            .frame(width: avatarSize, height: avatarSize)
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
