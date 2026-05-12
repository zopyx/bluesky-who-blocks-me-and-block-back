import SwiftUI

struct ThreadView: View {
    let postURI: String

    @StateObject private var viewModel = ThreadViewModel()
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var blueskyClient: LiveBlueskyClient
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    LoadingPanel(message: loc("profile.posts.loading"))
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        loc("list.detail.alert_title"),
                        systemImage: "exclamationmark.bubble",
                        description: Text(error)
                    )
                } else if let thread = viewModel.thread {
                    List {
                        threadPostRow(thread.post)
                        if let replies = thread.replies, !replies.isEmpty {
                            Section {
                                ForEach(Array(replies.enumerated()), id: \.offset) { _, reply in
                                    replyThreadRow(reply, depth: 0)
                                }
                            } header: {
                                Text(verbatim: loc("profile.posts.replies"))
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(loc("profile.posts.thread"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("actions.close")) { dismiss() }
                }
            }
            .task {
                guard let account = accountStore.activeAccount,
                      let appPassword = accountStore.appPassword(for: account) else {
                    viewModel.errorMessage = loc("list.detail.missing_creds")
                    return
                }
                await viewModel.loadThread(uri: postURI, account: account, appPassword: appPassword, using: blueskyClient)
            }
        }
    }

    @ViewBuilder
    private func threadPostRow(_ post: ThreadPostNode) -> some View {
        let author = post.author ?? RichAuthor(did: "", handle: "unknown", displayName: nil, avatar: nil)
        let record = post.record ?? RichRecord(text: "", createdAt: "")

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let avatar = author.avatar.flatMap(URL.init) {
                    AsyncImage(url: avatar) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.skyPrimary.opacity(0.16))
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.skyPrimary.opacity(0.16))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Text((author.displayName ?? author.handle ?? "?").prefix(1).uppercased())
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.skyPrimary)
                        }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(author.displayName ?? author.handle ?? "")
                        .font(.subheadline.weight(.semibold))
                    if let handle = author.handle {
                        Text("@\(handle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let created = record.createdAt, let date = parseDate(created) {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Text(record.text ?? "")
                .font(.body)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 16) {
                Label("\(post.replyCount ?? 0)", systemImage: "arrowshape.turn.up.left")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Label("\(post.repostCount ?? 0)", systemImage: "repeat")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Label("\(post.likeCount ?? 0)", systemImage: "heart")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
    }

    private func replyThreadRow(_ reply: ThreadNode, depth: Int) -> AnyView {
        let author = reply.post.author ?? RichAuthor(did: "", handle: "unknown", displayName: nil, avatar: nil)
        let record = reply.post.record ?? RichRecord(text: "", createdAt: "")

        let content = HStack(spacing: 6) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 2)
                .padding(.leading, CGFloat(depth) * 16)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if let avatar = author.avatar.flatMap(URL.init) {
                        AsyncImage(url: avatar) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.skyPrimary.opacity(0.16))
                        }
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.skyPrimary.opacity(0.16))
                            .frame(width: 28, height: 28)
                            .overlay {
                                Text((author.handle ?? "?").prefix(1).uppercased())
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color.skyPrimary)
                            }
                    }
                    Text(author.displayName ?? author.handle ?? "")
                        .font(.caption.weight(.semibold))
                    if let handle = author.handle {
                        Text("@\(handle)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Text(record.text ?? "")
                    .font(.subheadline)
                    .lineLimit(10)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let replies = reply.replies, !replies.isEmpty {
                    ForEach(Array(replies.enumerated()), id: \.offset) { _, child in
                        replyThreadRow(child, depth: depth + 1)
                    }
                }
            }
        }
        .listRowSeparator(.hidden)
        return AnyView(content)
    }
}

@MainActor
final class ThreadViewModel: ObservableObject {
    @Published private(set) var thread: ThreadNode?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func loadThread(uri: String, account: AppAccount, appPassword: String, using client: LiveBlueskyClient) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await client.fetchPostThread(uri: uri, account: account, appPassword: appPassword)
            thread = response.thread
        } catch {
            errorMessage = AppError.userMessage(from: error)
            AppLogger.moderation.error("Failed to load thread: \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }
}
