import SwiftUI

struct ActorSearchResultRow: View {
    let actor: BlueskyActor
    let isSelected: Bool
    let isAdding: Bool
    let toggleSelection: () -> Void
    let addAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggleSelection) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.skyPrimary : Color.secondary.opacity(0.45))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSelected ? "Deselect \(actor.handle)" : "Select \(actor.handle)")

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
            isSelected: false,
            isAdding: false,
            toggleSelection: {},
            addAction: {}
        )
    }
}
