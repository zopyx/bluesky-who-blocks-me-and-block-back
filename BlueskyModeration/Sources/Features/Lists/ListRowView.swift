import SwiftUI

struct ListRowView: View {
    let list: BlueskyList

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: list.kind.symbolName)
                .font(.headline)
                .foregroundStyle(list.kind == .moderation ? .orange : .skyPrimary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(list.name)
                    .font(.headline)
                Text(list.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(countText)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.primary)
                Text("members")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var countText: String {
        if let memberCount = list.memberCount {
            return "\(memberCount)"
        }

        return "-"
    }
}

#Preview {
    List {
        ListRowView(
            list: BlueskyList(
                id: "preview",
                name: "Trusted Sources",
                description: "Accounts curated for signal over noise.",
                memberCount: 67,
                kind: .regular
            )
        )
    }
}
