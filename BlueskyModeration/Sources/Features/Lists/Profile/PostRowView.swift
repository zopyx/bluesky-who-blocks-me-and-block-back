import SwiftUI

struct PostRowView: View {
    let entry: RichFeedEntry
    let onTapThread: () -> Void
    let onTapImage: (Int) -> Void
    var onPlayVideo: (() -> Void)?
    var onReply: (() -> Void)?
    var onLike: (() -> Void)?
    var onShowLikes: (() -> Void)?
    var isLiked: Bool = false
    var isReposted: Bool = false
    var onRepost: (() -> Void)?
    var onQuote: (() -> Void)?
    var onCopy: (() -> Void)?
    var onTranslate: (() -> Void)?
    var onOpenProfile: ((String) -> Void)?

    private var post: RichPost {
        entry.post
    }

    private var author: RichAuthor {
        post.safeAuthor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let url = author.avatar.flatMap(URL.init) {
                    ThumbnailImageView(url: url, maxPixelSize: 72) {
                        Circle().fill(Color.skyPrimary.opacity(0.16))
                    }
                    .scaledToFill()
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
                    Text(relativeTimeString(from: date))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Menu {
                    if let onCopy {
                        Button(action: onCopy) {
                            Label(loc("post.copy"), systemImage: "doc.on.doc")
                        }
                    }
                    if let onTranslate {
                        Button(action: onTranslate) {
                            Label(loc("post.translate"), systemImage: "globe")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                }
            }

            if let parent = entry.reply?.parent {
                let parentAuthor = parent.safeAuthor
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 2)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(parentAuthor.displayName ?? parentAuthor.handle ?? "")
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                            if let handle = parentAuthor.handle {
                                Text("@\(handle)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                        Text(parent.safeRecord.text ?? "")
                            .font(.caption2)
                            .lineLimit(2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(Color.skyPrimary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                Text(verbatim: "\(loc("profile.posts.replying_to")) @\(parentAuthor.handle ?? "")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Group {
                if let text = post.safeRecord.text, !text.isEmpty {
                    Text(mentionAttributedString(from: text))
                        .font(.body)
                        .lineLimit(6)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.openURL, OpenURLAction { url in
                            if url.scheme == "mention", let handle = url.host {
                                onOpenProfile?(handle)
                                return .handled
                            }
                            return .systemAction
                        })
                        .contentShape(Rectangle())
                        .onTapGesture { onTapThread() }
                }
            }

            if let video = post.embed?.video, let thumb = video.thumbnail, let url = URL(string: thumb) {
                Button {
                    if let onPlayVideo {
                        onPlayVideo()
                    }
                } label: {
                    ZStack {
                        ThumbnailImageView(url: url, maxPixelSize: 720) {
                            Rectangle().fill(Color.skyPrimary.opacity(0.08))
                        }
                        .scaledToFill()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                }
                .buttonStyle(.plain)
            }

            if let images = post.embed?.images, !images.isEmpty {
                let cols = images.count == 1 ? 1 : 2
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: cols), spacing: 4) {
                    ForEach(Array(images.prefix(4).enumerated()), id: \.offset) { index, item in
                        if let previewURL = item.fullsize.flatMap(URL.init) {
                            Button {
                                onTapImage(index)
                            } label: {
                                ThumbnailImageView(url: item.thumb.flatMap(URL.init) ?? previewURL, maxPixelSize: 512) {
                                    Rectangle().fill(Color.skyPrimary.opacity(0.08))
                                }
                                .scaledToFill()
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            actionBar
        }
    }

    private var actionBar: some View {
        HStack(spacing: 24) {
            actionButton(
                icon: "bubble.left",
                count: post.replyCount,
                action: onReply
            )
            Button(action: { onRepost?() }) {
                HStack(spacing: 4) {
                    Image(systemName: isReposted ? "repeat.circle.fill" : "repeat")
                        .font(.body.weight(.medium))
                    if let count = post.repostCount {
                        Text("\(count)")
                            .font(.callout)
                    }
                }
                .foregroundStyle(isReposted ? Color.green : Color.gray.opacity(0.6))
            }
            .buttonStyle(.plain)
            HStack(spacing: 4) {
                Button(action: { onLike?() }) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.body.weight(.medium))
                        .foregroundStyle(isLiked ? Color.red : Color.gray.opacity(0.6))
                }
                if let count = post.likeCount {
                    Button(action: { onShowLikes?() }) {
                        Text("\(count)")
                            .font(.callout)
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
            actionButton(
                icon: "quote.bubble",
                count: nil,
                action: onQuote
            )
        }
        .foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private func actionButton(icon: String, count: Int?, action: (() -> Void)?) -> some View {
        if let action {
            Button(action: action) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.body.weight(.medium))
                    if let count {
                        Text("\(count)")
                            .font(.callout)
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body.weight(.medium))
                if let count {
                    Text("\(count)")
                        .font(.callout)
                }
            }
        }
    }
}

func mentionAttributedString(from text: String) -> AttributedString {
    var attributed = AttributedString(text)
    guard let regex = try? NSRegularExpression(pattern: "@[a-zA-Z0-9_]([a-zA-Z0-9_.-]*[a-zA-Z0-9_])?") else { return attributed }
    let nsRange = NSRange(text.startIndex..., in: text)
    for match in regex.matches(in: text, range: nsRange).reversed() {
        guard let range = Range(match.range, in: text),
              let attrRange = Range(match.range, in: attributed) else { continue }
        let handle = String(text[range].dropFirst())
        attributed[attrRange].link = URL(string: "mention://\(handle)")
        attributed[attrRange].foregroundColor = Color.skyPrimary
        attributed[attrRange].underlineStyle = .single
    }
    return attributed
}
