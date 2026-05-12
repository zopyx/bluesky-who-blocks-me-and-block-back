import SwiftUI

struct BlueskyProfileView: View {
    let member: BlueskyListMember
    let list: BlueskyList?

    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @EnvironmentObject private var workspaceStore: ModerationWorkspaceStore
    @StateObject private var viewModel = BlueskyProfileViewModel()
    @State private var isShowingAvatarPreview = false

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
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    LabeledContent(loc("profile.stats.followers"), value: statText(profile.followersCount))
                    LabeledContent(loc("profile.stats.following"), value: statText(profile.followsCount))
                    LabeledContent(loc("profile.stats.posts"), value: statText(profile.postsCount))
                } header: {
                    Text(verbatim: loc("profile.stats"))
                }

                if !isOwnProfile {
                    Section {
                        if let viewerState = profile.viewerState {
                            Toggle(isOn: Binding(
                                get: { viewerState.isBlocking },
                                set: { _ in
                                    Task {
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
                            .accessibilityHint(viewerState.isBlocking ? "Turns off block for this account" : "Blocks this account from interacting with you")

                            Toggle(isOn: Binding(
                                get: { viewerState.muted },
                                set: { _ in
                                    Task {
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
                            .accessibilityHint(viewerState.muted ? "Unmutes this account" : "Mutes this account so you no longer see their posts")
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
                                    Task {
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
                                Task {
                                    await viewModel.blockAllFollowers(
                                        account: account,
                                        appPassword: appPassword,
                                        using: blueskyClient,
                                        queue: workspaceStore.actionQueue
                                    )
                                }
                            } label: {
                                Label { Text(verbatim: loc("profile.block_all")) } icon: { Image(systemName: "hand.raised.slash") }
                            }
                            .disabled(viewModel.isUpdatingModeration || viewModel.isBlockingFollowers)
                            .accessibilityHint("Blocks every account that follows this profile — queued as a background action")
                            Text(verbatim: loc("profile.block_all_warning"))
                                .font(.caption)
                                .foregroundStyle(.red)

                            if !ActionPresetStore.shared.presets.isEmpty {
                                Menu {
                                    ForEach(ActionPresetStore.shared.presets) { preset in
                                        Button(preset.name) {
                                            Task {
                                                if preset.shouldBlock {
                                                    await viewModel.toggleBlock(account: account, appPassword: appPassword, using: blueskyClient)
                                                }
                                                if preset.shouldMute {
                                                    await viewModel.toggleMute(account: account, appPassword: appPassword, using: blueskyClient)
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    Label(loc("profile.apply_preset"), systemImage: "square.2.layers.3d")
                                }
                                .accessibilityHint("Applies a saved action preset to this account")
                            }
                        }

                        if let list {
                            Label { Text(verbatim: loc("profile.member_of") + " \(list.name)") } icon: { Image(systemName: "person.2.badge.gearshape") }
                                .foregroundStyle(.secondary)
                        }

                    } header: {
                        Text(verbatim: loc("profile.actions_section"))
                    }
                }

                if let profileURL = profile.profileURL {
                    Section {
                        Link(destination: profileURL) {
                            Label { Text(verbatim: loc("profile.open_bluesky")) } icon: { Image(systemName: "arrow.up.right.square") }
                        }
                        .accessibilityHint("Opens this Bluesky profile in your default browser")
                    }
                }

                Section {
                    LabeledContent(loc("profile.stats.handle"), value: profile.handle)
                    LabeledContent(loc("profile.stats.did"), value: profile.did)
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
                                        .foregroundStyle(.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background {
                                            if #available(iOS 26, *) {
                                                Color.clear.glassEffect(.regular.tint(.green), in: .rect(cornerRadius: .infinity))
                                            } else {
                                                Color.clear.background(Color.green.opacity(0.12), in: Capsule())
                                            }
                                        }
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
            } else if viewModel.isLoading {
                LoadingPanel(message: loc("profile.loading"))
            }

            if let errorMessage = viewModel.errorMessage {
                ErrorRetryBanner(message: errorMessage) {
                    viewModel.errorMessage = nil
                    Task {
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
        .task {
            await viewModel.load(
                did: member.actor.did,
                account: account,
                appPassword: appPassword,
                using: blueskyClient
            )
        }
    }

    private func profileAvatar(for profile: BlueskyProfile) -> some View {
        Button {
            isShowingAvatarPreview = true
        } label: {
            if let avatarURL = profile.avatarURL {
                AsyncImage(url: avatarURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    avatarPlaceholder(for: profile)
                }
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
        return activeAccount.did != nil && profile.did == activeAccount.did
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
