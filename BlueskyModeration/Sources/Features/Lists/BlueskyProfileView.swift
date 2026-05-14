import SwiftUI

struct BlueskyProfileView: View {
    let member: BlueskyListMember
    let list: BlueskyList?

    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @EnvironmentObject private var workspaceStore: ModerationWorkspaceStore
    @StateObject private var viewModel = BlueskyProfileViewModel()
    @State private var isShowingAvatarPreview = false
    @State private var showPostBrowser = false
    @State private var showMediaBrowser = false
    @State private var shareFileURL: URL?
    @State private var loadTask: Task<Void, Never>?
    @State private var moderationTask: Task<Void, Never>?
    @State private var exportTask: Task<Void, Never>?
    @State private var blockedAccessType: BlockedAccessType?

    enum BlockedAccessType: String, Identifiable {
        case posts
        case media
        var id: String {
            rawValue
        }
    }

    var body: some View {
        Group {
            if let account = accountStore.activeAccount,
               let appPassword = accountStore.appPassword(for: account)
            {
                content(account: account, appPassword: appPassword)
            } else {
                ContentUnavailableView(
                    loc("list.detail.missing_creds"),
                    systemImage: "key.slash",
                    description: Text(loc("list.detail.missing_creds.desc"))
                )
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isShowingAvatarPreview, let avatarURL = viewModel.profile?.avatarURL {
                Color.black.opacity(0.9)
                    .ignoresSafeArea()
                    .onTapGesture { isShowingAvatarPreview = false }
                    .overlay {
                        AsyncImage(url: avatarURL) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .padding(40)
                        } placeholder: {
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        Button {
                            isShowingAvatarPreview = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white.opacity(0.8))
                                .padding()
                        }
                    }
                    .transition(.opacity.animation(UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut))
            }
        }
        .sheet(isPresented: $showPostBrowser) {
            if let profile = viewModel.profile {
                UserPostsView(did: profile.did, displayName: profile.displayName ?? profile.handle)
                    .environmentObject(accountStore)
                    .environmentObject(blueskyClient)
            }
        }
        .sheet(item: $shareFileURL) { url in
            ShareSheet(activityItems: [url])
        }
        .sheet(isPresented: $showMediaBrowser) {
            if let profile = viewModel.profile {
                MediaBrowserView(did: profile.did, handle: profile.handle)
                    .environmentObject(accountStore)
                    .environmentObject(blueskyClient)
            }
        }
        .sheet(item: $blockedAccessType) { type in
            NavigationStack {
                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "hand.raised.slash.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.red)
                        .symbolRenderingMode(.hierarchical)

                    VStack(spacing: 8) {
                        Text(verbatim: loc("profile.blocked.title"))
                            .font(.title2.weight(.bold))
                        Text(verbatim: loc("profile.blocked.\(type.rawValue)_desc"))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(loc("actions.got_it")) { blockedAccessType = nil }
                    }
                }
            }
            .presentationDetents([.height(320)])
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func content(account: AppAccount, appPassword: String) -> some View {
        List {
            if let profile = viewModel.profile {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 14) {
                            profileAvatar(for: profile)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.title)
                                    .font(.title3.weight(.semibold))
                                Text(profile.handle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let description = profile.description, !description.isEmpty {
                            Text(description)
                                .font(.body)
                        }

                        if !isOwnProfile, let state = profile.viewerState {
                            relationshipBadges(state: state)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    NavigationLink {
                        RelationshipsView(mode: .followers, initialCount: profile.followersCount, profileDID: profile.did, profileHandle: profile.handle)
                    } label: {
                        HStack {
                            Text(verbatim: loc("profile.stats.followers"))
                            Spacer()
                            Text(statText(profile.followersCount))
                                .foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink {
                        RelationshipsView(mode: .following, initialCount: profile.followsCount, profileDID: profile.did, profileHandle: profile.handle)
                    } label: {
                        HStack {
                            Text(verbatim: loc("profile.stats.following"))
                            Spacer()
                            Text(statText(profile.followsCount))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        if profile.viewerState?.blockedBy == true {
                            blockedAccessType = .posts
                        } else {
                            showPostBrowser = true
                        }
                    } label: {
                        HStack {
                            Text(loc("profile.stats.posts"))
                            Spacer()
                            Text(statText(profile.postsCount))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    Button {
                        if profile.viewerState?.blockedBy == true {
                            blockedAccessType = .media
                        } else {
                            showMediaBrowser = true
                        }
                    } label: {
                        HStack {
                            Text(loc("profile.stats.media"))
                            Spacer()
                            if viewModel.isScanningMedia {
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else if viewModel.mediaImageCount > 0 || viewModel.mediaVideoCount > 0 {
                                Text([
                                    viewModel.mediaImageCount > 0 ? "\(viewModel.mediaImageCount) image\(viewModel.mediaImageCount != 1 ? "s" : "")" : nil,
                                    viewModel.mediaVideoCount > 0 ? "\(viewModel.mediaVideoCount) video\(viewModel.mediaVideoCount != 1 ? "s" : "")" : nil,
                                ].compactMap(\.self).joined(separator: " · "))
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text(verbatim: loc("profile.stats"))
                        .onTapGesture(count: 2) { showPostBrowser = true }
                }

                if !isOwnProfile {
                    Section {
                        if let viewerState = profile.viewerState {
                            Toggle(isOn: Binding(
                                get: { viewerState.isBlocking },
                                set: { _ in
                                    runModeration {
                                        await viewModel.toggleBlock(
                                            account: account,
                                            appPassword: appPassword,
                                            using: blueskyClient
                                        )
                                    }
                                }
                            )) {
                                Label { Text(verbatim: loc("profile.block")) } icon: { Image(systemName: "hand.raised") }
                            }
                            .disabled(viewModel.isUpdatingModeration)
                            .accessibilityHint(viewerState.isBlocking ? loc("profile.unblock.hint") : loc("profile.block.hint"))

                            Toggle(isOn: Binding(
                                get: { viewerState.muted },
                                set: { _ in
                                    runModeration {
                                        await viewModel.toggleMute(
                                            account: account,
                                            appPassword: appPassword,
                                            using: blueskyClient
                                        )
                                    }
                                }
                            )) {
                                Label { Text(verbatim: loc("profile.mute")) } icon: { Image(systemName: "speaker.slash") }
                            }
                            .disabled(viewModel.isUpdatingModeration)
                            .accessibilityHint(viewerState.muted ? loc("profile.unmute.hint") : loc("profile.mute.hint"))
                        }

                        if let statusMessage = viewModel.statusMessage {
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text(verbatim: loc("profile.moderation_section"))
                    }
                }

                if !isOwnProfile, !viewModel.listMemberships.isEmpty {
                    let sortedMemberships = viewModel.listMemberships.sorted { $0.kind == .moderation && $1.kind != .moderation }
                    Section {
                        ForEach(sortedMemberships) { membership in
                            Toggle(isOn: Binding(
                                get: { membership.isMember },
                                set: { _ in
                                    runModeration {
                                        await viewModel.toggleListMembership(
                                            membership,
                                            account: account,
                                            appPassword: appPassword,
                                            using: blueskyClient
                                        )
                                    }
                                }
                            )) {
                                HStack(spacing: 8) {
                                    Text(membership.name)
                                    if membership.kind == .moderation {
                                        Text(verbatim: loc("profile.moderation_section"))
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(Color.skyPrimary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.skyPrimary.opacity(0.12), in: Capsule())
                                    }
                                }
                            }
                            .disabled(viewModel.isUpdatingModeration)
                        }
                    } header: {
                        Text(verbatim: loc("lists.lists"))
                    }
                }

                if let profileURL = profile.profileURL {
                    Section {
                        Link(destination: profileURL) {
                            Label { Text(verbatim: loc("profile.open_bluesky")) } icon: { Image(systemName: "arrow.up.right.square") }
                        }
                        .accessibilityHint(loc("profile.open_bluesky.hint"))
                    }
                }

                Section {
                    LabeledContent {
                        HStack(spacing: 4) {
                            Text(profile.handle)
                                .lineLimit(1)
                            Button {
                                UIPasteboard.general.string = profile.handle
                                viewModel.statusMessage = "Handle copied"
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tertiary)
                        }
                    } label: {
                        Text(loc("profile.stats.handle"))
                    }
                    LabeledContent {
                        HStack(spacing: 4) {
                            Text(profile.did)
                                .lineLimit(1)
                                .font(.caption.monospaced())
                            Button {
                                UIPasteboard.general.string = profile.did
                                viewModel.statusMessage = "DID copied"
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tertiary)
                        }
                    } label: {
                        Text(loc("profile.stats.did"))
                    }
                    if let createdAt = profile.createdAt {
                        LabeledContent(loc("profile.stats.joined"), value: createdAt.formatted(date: .abbreviated, time: .omitted))
                    }
                    if !profile.labels.isEmpty {
                        LabeledContent(loc("profile.stats.labels"), value: profile.labels.joined(separator: ", "))
                    }
                } header: {
                    Text(verbatim: loc("profile.account_info"))
                }

                if !viewModel.handleHistory.isEmpty {
                    Section {
                        ForEach(viewModel.handleHistory) { entry in
                            HStack {
                                Text(entry.handle)
                                    .font(.caption.monospaced())
                                if entry.isCurrent {
                                    Text(verbatim: loc("profile.current_badge"))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(.green))
                                }
                                Spacer()
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } header: {
                        Text(verbatim: loc("profile.handle_history"))
                    }
                }

                if !isOwnProfile {
                    Section {
                        if viewModel.isBlockingFollowers {
                            if let progress = viewModel.blockFollowersProgress {
                                BatchProgressCard(
                                    title: progress.title,
                                    completedCount: progress.completedCount,
                                    totalCount: progress.totalCount,
                                    currentHandle: progress.currentHandle
                                )
                            }
                        } else {
                            Button(role: .destructive) {
                                runModeration {
                                    await viewModel.blockAllFollowers(
                                        account: account,
                                        appPassword: appPassword,
                                        using: blueskyClient,
                                        queue: workspaceStore.actionQueue
                                    )
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "hand.raised.slash")
                                    Text(verbatim: loc("profile.block_all"))
                                    Text(verbatim: loc("profile.beta"))
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(.orange))
                                }
                            }
                            .disabled(true)
                            .accessibilityHint(loc("profile.block_all.hint"))
                            HStack(spacing: 8) {
                                Image(systemName: "hand.raised.slash")
                                    .hidden()
                                Text(verbatim: loc("profile.block_all_warning"))
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }

                        if let list {
                            Label { Text(verbatim: loc("profile.member_of").replacingOccurrences(of: "{list}", with: list.name)) } icon: { Image(systemName: "person.2.badge.gearshape") }
                                .foregroundStyle(.secondary)
                        }

                    } header: {
                        Text(verbatim: loc("profile.actions_section"))
                    }
                }
            } else if viewModel.isLoading {
                LoadingPanel(message: loc("profile.loading"))
            }

            if let errorMessage = viewModel.errorMessage {
                ErrorRetryBanner(message: errorMessage) {
                    viewModel.errorMessage = nil
                    startLoadTask {
                        await viewModel.load(
                            did: member.actor.did,
                            account: account,
                            appPassword: appPassword,
                            using: blueskyClient
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await runLoad {
                await viewModel.load(
                    did: member.actor.did,
                    account: account,
                    appPassword: appPassword,
                    using: blueskyClient
                )
            }
        }
        .task {
            await runLoad {
                await viewModel.loadIfNeeded(
                    did: member.actor.did,
                    account: account,
                    appPassword: appPassword,
                    using: blueskyClient
                )
            }
        }
        .onDisappear {
            loadTask?.cancel()
            moderationTask?.cancel()
            exportTask?.cancel()
        }
    }

    private func profileAvatar(for profile: BlueskyProfile) -> some View {
        Button {
            isShowingAvatarPreview = true
        } label: {
            if let avatarURL = profile.avatarURL {
                ThumbnailImageView(url: avatarURL, maxPixelSize: 144) {
                    avatarPlaceholder(for: profile)
                }
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                }
            } else {
                avatarPlaceholder(for: profile)
            }
        }
    }

    private func avatarPlaceholder(for profile: BlueskyProfile) -> some View {
        Circle()
            .fill(Color.skyPrimary.opacity(0.16))
            .frame(width: 72, height: 72)
            .overlay {
                Text(profile.title.prefix(1).uppercased())
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.skyPrimary)
            }
    }

    private func statText(_ value: Int?) -> String {
        if let value {
            return "\(value)"
        }

        return "-"
    }

    private var isOwnProfile: Bool {
        guard let profile = viewModel.profile,
              let activeAccount = accountStore.activeAccount else { return false }
        if let activeDID = activeAccount.did, activeDID == profile.did { return true }
        return activeAccount.handle.lowercased() == profile.handle.lowercased()
    }

    @ViewBuilder
    private func relationshipBadges(state: BlueskyViewerState) -> some View {
        let badges: [(label: String, icon: String, color: Color, active: Bool)] = [
            (loc("profile.badge.follows_me"), "person.crop.circle.badge.checkmark", .green, state.followsYou),
            (loc("profile.badge.blocks_me"), "hand.raised.slash.fill", .red, state.blockedBy),
            (loc("profile.badge.following"), "heart.fill", .blue, state.isFollowing),
            (loc("profile.badge.blocking"), "hand.raised.fill", .orange, state.isBlocking),
        ]
        let active = badges.filter(\.active)
        if !active.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(active, id: \.label) { badge in
                        HStack(spacing: 4) {
                            Image(systemName: badge.icon)
                                .font(.caption2)
                            Text(badge.label)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(badge.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(badge.color.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
    }

    private func statusChip(title: String, tint: Color, emphasized: Bool) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(emphasized ? tint : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if #available(iOS 26, *) {
                    Color.clear.glassEffect(.regular.tint(emphasized ? tint : Color.secondary), in: .rect(cornerRadius: .infinity))
                } else {
                    Color.clear.background((emphasized ? tint : Color.secondary).opacity(0.12), in: Capsule())
                }
            }
    }

    private func runModeration(_ operation: @escaping @Sendable () async -> Void) {
        moderationTask?.cancel()
        moderationTask = Task {
            await operation()
        }
    }

    private func runExport(_ format: ExportFileFormat, account: AppAccount, appPassword: String) {
        exportTask?.cancel()
        exportTask = Task {
            if let url = await viewModel.exportPosts(as: format, account: account, appPassword: appPassword, using: blueskyClient) {
                shareFileURL = url
            }
        }
    }

    private func runLoad(
        operation: @escaping @Sendable () async -> Void
    ) async {
        let task = startLoadTask(operation: operation)
        await task.value
    }

    @discardableResult
    private func startLoadTask(
        operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        loadTask?.cancel()
        let task = Task {
            await operation()
        }
        loadTask = task
        return task
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

#Preview {
    NavigationStack {
        BlueskyProfileView(
            member: BlueskyListMember(
                recordURI: "at://did:plc:preview/app.bsky.graph.listitem/1",
                actor: BlueskyActor(did: "did:plc:1", handle: "alice.bsky.social", displayName: "Alice Chen")
            ),
            list: BlueskyList(
                id: "at://did:plc:preview/app.bsky.graph.list/123",
                name: "Trusted Sources",
                description: "Accounts curated for signal over noise.",
                memberCount: 67,
                kind: .regular
            )
        )
    }
    .environmentObject(AccountStore(preview: true))
    .environmentObject(PreviewBlueskyClient())
}
