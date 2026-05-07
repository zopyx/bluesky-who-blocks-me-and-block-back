import SwiftUI

struct BlueskyActorRow: View {
    let actor: BlueskyActor

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.skyPrimary.opacity(0.16))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(actor.title.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(Color.skyPrimary)
                }

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
}

#Preview {
    List {
        BlueskyActorRow(
            actor: BlueskyActor(did: "did:plc:demo", handle: "alice.bsky.social", displayName: "Alice Chen")
        )
    }
}
