import SwiftUI

struct ActorSearchResultRow: View {
    let actor: BlueskyActor
    let isAdding: Bool
    let addAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            BlueskyActorRow(actor: actor)

            Button {
                addAction()
            } label: {
                if isAdding {
                    ProgressView()
                        .frame(width: 24, height: 24)
                } else {
                    Text("Add")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.skyPrimary.opacity(0.14), in: Capsule())
                        .foregroundStyle(Color.skyPrimary)
                }
            }
            .buttonStyle(.plain)
            .disabled(isAdding)
        }
    }
}

#Preview {
    List {
        ActorSearchResultRow(
            actor: BlueskyActor(did: "did:plc:demo", handle: "alice.bsky.social", displayName: "Alice Chen"),
            isAdding: false,
            addAction: {}
        )
    }
}
