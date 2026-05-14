import SwiftUI

struct ListRowView: View {
    let list: BlueskyList
    @ScaledMetric private var iconSize = 36

    var body: some View {
        HStack(spacing: 14) {
            if let avatarURL = list.avatarURL {
                AsyncImage(url: avatarURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    listIcon
                }
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.separator, lineWidth: 0.5)
                }
            } else {
                listIcon
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(list.name)
                    .appFont(.subheading)
                Text(list.description)
                    .appFont(.label)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if let memberCount = list.memberCount {
                Text("\(memberCount)")
                    .appFont(.statistic)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.secondary.opacity(0.1))
                    )
            }
        }
        .padding(.vertical, 6)
        .appScrollTransition()
    }

    private var listIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(list.kind == .moderation ? Color.orange.opacity(0.12) : Color.skyPrimary.opacity(0.12))
                .frame(width: iconSize, height: iconSize)
            Image(systemName: list.kind.symbolName)
                .font(.headline)
                .foregroundStyle(list.kind == .moderation ? .orange : .skyPrimary)
        }
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
