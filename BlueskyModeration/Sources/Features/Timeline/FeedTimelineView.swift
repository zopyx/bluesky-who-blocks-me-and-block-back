import SwiftUI

struct FeedTimelineView: View {
    @StateObject private var viewModel = FeedTimelineViewModel()
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var blueskyClient: LiveBlueskyClient
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPostURI: String?
    @State private var imagePreview: ImagePreviewCollection?
    @State private var videoPreviewURL: URL?
    @State private var showLikesForURI: String?
    @State private var initialLoadTask: Task<Void, Never>?
    @State private var loadMoreTask: Task<Void, Never>?
    @State private var composeContext: ComposeContext?
    @State private var showFeedPicker = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading, viewModel.entries.isEmpty {
                    LoadingPanel(message: loc("timeline.loading"))
                } else if let error = viewModel.errorMessage, viewModel.entries.isEmpty {
                    ContentUnavailableView(
                        loc("list.detail.alert_title"),
                        systemImage: "exclamationmark.bubble",
                        description: Text(error)
                    )
                } else if viewModel.entries.isEmpty {
                    ContentUnavailableView(
                        loc("timeline.empty"),
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text(verbatim: loc("timeline.empty_desc"))
                    )
                } else {
                    listContent
                }
            }
            .navigationTitle(loc("timeline.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("actions.close")) { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showFeedPicker = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text(viewModel.feedStore.customFeedName)
                                .font(.caption)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await refresh() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: .command)
                }
            }
            .sheet(item: $selectedPostURI) { uri in
                ThreadView(postURI: uri)
                    .environmentObject(accountStore)
                    .environmentObject(blueskyClient)
            }
            .fullScreenCover(item: $imagePreview) { preview in
                ImageCarouselView(urls: preview.urls, initialIndex: preview.initialIndex) {
                    imagePreview = nil
                }
            }
            .fullScreenCover(item: $videoPreviewURL) { url in
                VideoPlayerView(url: url) {
                    videoPreviewURL = nil
                }
            }
            .sheet(item: $showLikesForURI) { uri in
                LikesListView(uri: uri)
                    .environmentObject(accountStore)
                    .environmentObject(blueskyClient)
            }
            .sheet(isPresented: $showFeedPicker) {
                FeedPickerView(feedStore: viewModel.feedStore)
            }
            .sheet(item: $composeContext) { context in
                if context.isReply {
                    ComposePostView(
                        account: context.account,
                        appPassword: context.appPassword,
                        blueskyClient: blueskyClient,
                        onComplete: { refreshAfterAction() },
                        replyTo: (context.parentURI, context.parentCID, context.rootURI, context.rootCID)
                    )
                    .environmentObject(accountStore)
                    .environmentObject(blueskyClient)
                } else {
                    ComposePostView(
                        account: context.account,
                        appPassword: context.appPassword,
                        blueskyClient: blueskyClient,
                        onComplete: { refreshAfterAction() },
                        quote: (context.uri, context.cid)
                    )
                    .environmentObject(accountStore)
                    .environmentObject(blueskyClient)
                }
            }
            .task {
                await loadInitial()
            }
            .onDisappear {
                initialLoadTask?.cancel()
                loadMoreTask?.cancel()
            }
        }
    }

    private var listContent: some View {
        List {
            ForEach(viewModel.entries, id: \.post.uri) { entry in
                if viewModel.mutedWords.contains(entry.post.safeRecord.text ?? "") {
                    EmptyView()
                } else {
                    PostRowView(
                        entry: entry,
                        onTapThread: {
                            selectedPostURI = entry.post.uri
                        },
                        onTapImage: { index in
                            let allImages = entry.post.embed?.images ?? []
                            let urls = allImages.compactMap { $0.fullsize.flatMap(URL.init) }
                            guard index < urls.count else { return }
                            imagePreview = ImagePreviewCollection(urls: urls, initialIndex: index)
                        },
                        onPlayVideo: {
                            if let playlist = entry.post.embed?.video?.playlist, let url = URL(string: playlist) {
                                videoPreviewURL = url
                            }
                        },
                        onReply: { handleReply(entry) },
                        onLike: { handleLike(entry) },
                        onShowLikes: { showLikesForURI = entry.post.uri },
                        isLiked: entry.post.isLikedByMe,
                        isReposted: entry.post.isRepostedByMe,
                        onRepost: { handleRepost(entry) },
                        onQuote: { handleQuote(entry) },
                        onCopy: { UIPasteboard.general.string = entry.post.safeRecord.text },
                        onTranslate: { translateText(entry.post.safeRecord.text ?? "") },
                        onOpenProfile: { handle in openProfile(handle) }
                    )
                    .onAppear {
                        if entry.post.uri == viewModel.entries.last?.post.uri {
                            Task { await loadMore() }
                        }
                    }
                }
            }
            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
            if !viewModel.hasMore, !viewModel.entries.isEmpty {
                Text(verbatim: loc("timeline.end"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await refresh()
        }
        .overlay(alignment: .top) {
            if viewModel.newPostCount > 0 {
                newPostsBanner
            }
        }
    }

    private func handleReply(_ entry: RichFeedEntry) {
        guard let account = accountStore.activeAccount,
              let appPassword = accountStore.appPassword(for: account),
              let cid = entry.post.cid else { return }
        let uri = entry.post.uri
        composeContext = ComposeContext(
            account: account,
            appPassword: appPassword,
            isReply: true,
            parentURI: uri,
            parentCID: cid,
            rootURI: uri,
            rootCID: cid
        )
    }

    private func handleLike(_ entry: RichFeedEntry) {
        guard let account = accountStore.activeAccount,
              let appPassword = accountStore.appPassword(for: account),
              let cid = entry.post.cid else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            do {
                if entry.post.isLikedByMe, let likeURI = entry.post.myLikeURI {
                    _ = try await blueskyClient.deleteRecord(recordURI: likeURI, account: account, appPassword: appPassword)
                } else {
                    _ = try await blueskyClient.createLike(uri: entry.post.uri, cid: cid, account: account, appPassword: appPassword)
                }
                await refresh()
            } catch {
                AppLogger.moderation.error("Like failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func handleRepost(_ entry: RichFeedEntry) {
        guard let account = accountStore.activeAccount,
              let appPassword = accountStore.appPassword(for: account),
              let cid = entry.post.cid else { return }
        Task {
            do {
                if entry.post.isRepostedByMe, let repostURI = entry.post.myRepostURI {
                    _ = try await blueskyClient.deleteRecord(recordURI: repostURI, account: account, appPassword: appPassword)
                } else {
                    _ = try await blueskyClient.createRepost(uri: entry.post.uri, cid: cid, account: account, appPassword: appPassword)
                }
                await refresh()
            } catch {
                AppLogger.moderation.error("Repost failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func handleQuote(_ entry: RichFeedEntry) {
        guard let account = accountStore.activeAccount,
              let appPassword = accountStore.appPassword(for: account),
              let cid = entry.post.cid else { return }
        composeContext = ComposeContext(
            account: account,
            appPassword: appPassword,
            isReply: false,
            uri: entry.post.uri,
            cid: cid
        )
    }

    private func refreshAfterAction() {
        Task { await refresh() }
    }

    private func loadInitial() async {
        guard let account = accountStore.activeAccount,
              let appPassword = accountStore.appPassword(for: account) else { return }
        initialLoadTask?.cancel()
        let task = Task {
            await viewModel.loadTimeline(account: account, appPassword: appPassword, using: blueskyClient)
        }
        initialLoadTask = task
        await task.value
    }

    private func loadMore() async {
        guard let account = accountStore.activeAccount,
              let appPassword = accountStore.appPassword(for: account) else { return }
        guard loadMoreTask == nil else { return }
        let task = Task {
            await viewModel.loadMore(account: account, appPassword: appPassword, using: blueskyClient)
        }
        loadMoreTask = task
        await task.value
        loadMoreTask = nil
    }

    private func openProfile(_ handle: String) {
        guard let url = URL(string: "https://bsky.app/profile/\(handle)") else { return }
        UIApplication.shared.open(url)
    }

    private var newPostsBanner: some View {
        Text(loc("timeline.new_posts").replacingOccurrences(of: "{n}", with: "\(viewModel.newPostCount)"))
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.skyPrimary))
            .padding(.top, 8)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.newPostCount = 0
                }
                Task { await refresh() }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                withAnimation { viewModel.newPostCount = 0 }
            }
    }

    private func translateText(_ text: String) {
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://translate.google.com/?text=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }

    private func refresh() async {
        guard let account = accountStore.activeAccount,
              let appPassword = accountStore.appPassword(for: account) else { return }
        await viewModel.refresh(account: account, appPassword: appPassword, using: blueskyClient)
    }
}

private struct ComposeContext: Identifiable {
    let id = UUID()
    let account: AppAccount
    let appPassword: String
    let isReply: Bool
    var parentURI: String = ""
    var parentCID: String = ""
    var rootURI: String = ""
    var rootCID: String = ""
    var uri: String = ""
    var cid: String = ""
}

#Preview {
    FeedTimelineView()
        .environmentObject(AccountStore(preview: true))
        .environmentObject(PreviewBlueskyClient())
}
