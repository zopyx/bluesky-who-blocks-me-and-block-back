import SwiftUI

struct AccountRowView: View {
    let account: BlueskyAccount
    let isActive: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Avatar placeholder
            ZStack {
                Circle()
                    .fill(isActive ? Color.accentColor.opacity(0.15) : Color(.systemGray5))
                    .frame(width: 44, height: 44)

                Text(String(account.handle.prefix(1).uppercased()))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isActive ? .accent : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(account.handle)")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let did = account.did {
                    Text(did)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if let lastUsed = account.lastUsedAt {
                    Text("Last used \(lastUsed.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.accent)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityLabel("Active account")
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Account @\(account.handle)\(isActive ? ", active" : "")")
    }
}

#Preview {
    List {
        AccountRowView(
            account: BlueskyAccount(handle: "alice.bsky.social", did: "did:plc:abc123", isActive: true),
            isActive: true
        )
        AccountRowView(
            account: BlueskyAccount(handle: "bob.bsky.social", did: "did:plc:def456"),
            isActive: false
        )
    }
}
