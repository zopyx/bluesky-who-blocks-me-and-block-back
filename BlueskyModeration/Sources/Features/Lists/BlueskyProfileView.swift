import SwiftUI

struct BlueskyProfileView: View {
    let member: BlueskyListMember
    let list: BlueskyList?

    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @EnvironmentObject private var workspaceStore: ModerationWorkspaceStore
    @EnvironmentObject private var notesStore: ProfileNotesStore
    @StateObject private var viewModel = BlueskyProfileViewModel()
    @State private var isShowingNote = false

    var body: some View {
        Group {
            if let account = accountStore.activeAccount,
               let appPassword = accountStore.appPassword(for: account) {
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

        }

    @ViewBuilder
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

                if !isOwnProfile, !moderationMemberships.isEmpty {
                    Section {
                        ForEach(moderationMemberships) { membership in
                            membershipButton(
                                membership: membership,
                                account: account,
                                appPassword: appPassword
                            )
                        }
                    } header: {
                        Text(verbatim: loc("profile.moderation_lists_section"))
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
                        Button {
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
                    }

                    if let list {
                        Label { Text(verbatim: loc("profile.member_of") + " \(list.name)") } icon: { Image(systemName: "person.2.badge.gearshape") }
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        isShowingNote = true
                    } label: {
                        Label { Text(verbatim: notesStore.note(for: profile.did).isEmpty ? loc("profile.add_note") : loc("profile.edit_note")) } icon: { Image(systemName: "note.text") }
                    }
                    .accessibilityHint("Opens a note editor to record information about this account")
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
                Section {
                    SkeletonCard()
                }
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
        .sheet(isPresented: $isShowingNote) {
            if let profile = viewModel.profile {
                NoteSheet(profile: profile, notesStore: notesStore)
            }
        }
    }

    @ViewBuilder
    private func profileAvatar(for profile: BlueskyProfile) -> some View {
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

    private var moderationMemberships: [ProfileListMembership] {
        let moderationLists = viewModel.listMemberships.filter { $0.kind == .moderation }
        if moderationLists.isEmpty {
            return viewModel.listMemberships
        }
        return moderationLists
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

    private func membershipButton(
        membership: ProfileListMembership,
        account: AppAccount,
        appPassword: String
    ) -> some View {
        Button {
            Task {
                await viewModel.toggleListMembership(
                    membership,
                    account: account,
                    appPassword: appPassword,
                    using: blueskyClient
                )
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(membership.name)
                    Text(verbatim: membership.isMember ? loc("profile.already_included") : loc("profile.tap_to_add"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(verbatim: membership.isMember ? loc("profile.remove") : loc("profile.add"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(membership.isMember ? .red : Color.skyPrimary)
            }
        }
        .disabled(viewModel.isUpdatingModeration)
        .accessibilityHint(membership.isMember ? "Removes this profile from the list \(membership.name)" : "Adds this profile to the list \(membership.name)")
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
