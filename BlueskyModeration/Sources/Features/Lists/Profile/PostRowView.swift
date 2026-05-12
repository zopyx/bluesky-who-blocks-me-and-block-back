import SwiftUI

struct PostRowView: View {
    let entry: RichFeedEntry
    let onTapThread: () -> Void
    let onTapImage: (URL) -> Void

    private var post: RichPost { entry.post }
    private var author: RichAuthor { post.safeAuthor }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let url = author.avatar.flatMap(URL.init) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.skyPrimary.opacity(0.16))
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.skyPrimary.opacity(0.16))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Text((author.displayName ?? author.handle ?? "?").prefix(1).uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.skyPrimary)
                        }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(author.displayName ?? author.handle ?? "")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if let handle = author.handle {
                        Text("@\(handle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let created = post.safeRecord.createdAt, let date = parseDate(created) {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Button(action: onTapThread) {
                Text(post.safeRecord.text ?? "")
                    .font(.body)
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if let images = post.embed?.images, !images.isEmpty {
                let cols = images.count == 1 ? 1 : 2
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: cols), spacing: 4) {
                    ForEach(Array(images.prefix(4).enumerated()), id: \.offset) { _, item in
                        if let fullsize = item.fullsize, let url = URL(string: fullsize) {
                            Button {
                                onTapImage(url)
                            } label: {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Rectangle().fill(Color.skyPrimary.opacity(0.08))
                                }
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Button(action: onTapThread) {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.left")
                            .font(.caption2)
                        Text("\(post.replyCount ?? 0)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                    HStack(spacing: 4) {
                        Image(systemName: "repeat")
                            .font(.caption2)
                        Text("\(post.repostCount ?? 0)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                            .font(.caption2)
                        Text("\(post.likeCount ?? 0)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
