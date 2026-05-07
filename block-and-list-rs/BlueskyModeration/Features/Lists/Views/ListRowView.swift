import SwiftUI

struct ListRowView: View {
    let list: BlueskyList

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBackgroundColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: list.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(list.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let description = list.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Text(list.displayPurpose)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(iconColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(iconBackgroundColor.opacity(0.12))
                        .clipShape(Capsule())

                    Text("by @\(list.creatorHandle)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(list.name), \(list.displayPurpose) list by @\(list.creatorHandle)")
    }

    private var iconColor: Color {
        switch list.purpose {
        case .curation: return .blue
        case .moderation: return .orange
        }
    }

    private var iconBackgroundColor: Color {
        switch list.purpose {
        case .curation: return .blue
        case .moderation: return .orange
        }
    }
}

#Preview {
    List {
        ListRowView(list: BlueskyList(
            uri: "at://did:plc:abc/app.bsky.graph.list/123",
            cid: "abc",
            name: "Cool People",
            description: "A curated list of interesting accounts to follow",
            purpose: .curation,
            creatorHandle: "alice.bsky.social",
            creatorDid: "did:plc:abc",
            indexedAt: Date()
        ))
        ListRowView(list: BlueskyList(
            uri: "at://did:plc:abc/app.bsky.graph.list/456",
            cid: "def",
            name: "Spam Blockers",
            description: "Accounts flagged for spam behavior",
            purpose: .moderation,
            creatorHandle: "alice.bsky.social",
            creatorDid: "did:plc:abc",
            indexedAt: Date()
        ))
    }
}
