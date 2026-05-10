import SwiftUI

enum RelationshipMode: String, CaseIterable {
    case followers
    case following
    case blocking
    case blockedBy

    var title: String {
        switch self {
        case .followers: return "My followers"
        case .following: return "My followings"
        case .blocking: return "Blocking"
        case .blockedBy: return "Blocked by"
        }
    }

    func titled(_ count: Int) -> String {
        "\(title) (\(count))"
    }
}

struct RelationshipsView: View {
    let mode: RelationshipMode
    let initialCount: Int?
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @AppStorage("debugMode") private var debugMode = false
    @State private var actors: [BlueskyActor] = []
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var searchQuery = ""
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var selectedActorForList: BlueskyActor?
    @State private var isShowingListPicker = false
    @State private var isShowingBlockConfirm = false
    @State private var actorToBlock: BlueskyActor?

    private var filteredActors: [BlueskyActor] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return actors }
        return actors.filter {
            $0.handle.lowercased().contains(trimmed) ||
            ($0.displayName?.lowercased().contains(trimmed) ?? false)
        }
    }

    private var modeLocalized: String {
        switch mode {
        case .followers: return loc("rel.mode.followers")
        case .following: return loc("rel.mode.following")
        case .blocking: return loc("rel.mode.blocking")
        case .blockedBy: return loc("rel.mode.blocked_by")
        }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView(loc("rel.loading").replacingOccurrences(of: "{mode}", with: modeLocalized.lowercased()))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ErrorRetryBanner(message: errorMessage) {
                    Task { await load() }
                }
            } else {
                List {
                    Section {
                        Text("\(modeLocalized) (\(isLoading ? (initialCount ?? 0) : actors.count))")
                            .font(.title2.weight(.bold))
                    }

                    if !actors.isEmpty {
                        Section {
                            TextField(loc("rel.search_placeholder").replacingOccurrences(of: "{mode}", with: modeLocalized.lowercased()), text: $searchQuery)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            if let statusMessage {
                                Text(statusMessage)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    if filteredActors.isEmpty && !isLoading {
                        ContentUnavailableView {
                            Label(modeLocalized, systemImage: "person.3")
                        } description: {
                            Text(searchQuery.isEmpty ? loc("rel.no_accounts") : loc("rel.no_matches"))
                        }
                    } else {
                        ForEach(Array(filteredActors.enumerated()), id: \.element.id) { index, actor in
                            NavigationLink {
                                BlueskyProfileView(
                                    member: BlueskyListMember(recordURI: "rel:\(actor.did)", actor: actor),
                                    list: nil
                                )
                            } label: {
                                HStack(spacing: 8) {
                                    avatarView(for: actor)

                                    VStack(alignment: .leading, spacing: 1) {
                                        HStack(spacing: 6) {
                                            Text(actor.title)
                                                .font(.subheadline.weight(.semibold))
                                            if actor.isNew {
                                                Text(loc("rel.new_badge"))
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundStyle(.orange)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1)
                                                    .background(Color.orange.opacity(0.12), in: Capsule())
                                            }
                                        }
                                        Text(actor.handle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if debugMode {
                                        Text("\(index + 1)")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    actorToBlock = actor
                                    isShowingBlockConfirm = true
                                } label: {
                                    Label(loc("rel.block"), systemImage: "hand.raised.fill")
                                }
                                .accessibilityHint("Blocks this account from interacting with you")

                                Button {
                                    selectedActorForList = actor
                                    isShowingListPicker = true
                                } label: {
                                    Label(loc("rel.add_to_list"), systemImage: "list.bullet")
                                }
                                .accessibilityHint("Adds this account to one of your moderation lists")
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    actorToBlock = actor
                                    isShowingBlockConfirm = true
                                } label: {
                                    Label(loc("rel.block"), systemImage: "hand.raised.fill")
                                }
                                .accessibilityHint("Blocks this account — swipe action")
                            }
                        }
                        .onDelete { indexSet in
                            if let idx = indexSet.first, idx < filteredActors.count {
                                actorToBlock = filteredActors[idx]
                                isShowingBlockConfirm = true
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !actors.isEmpty {
                    ShareLink(item: csvContent, subject: Text(loc("rel.export_subject").replacingOccurrences(of: "{mode}", with: modeLocalized)), message: Text(loc("rel.export_message").replacingOccurrences(of: "{mode}", with: modeLocalized.lowercased()))) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityHint("Shares a CSV export of these accounts")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if isLoading && actors.isEmpty {
                    ProgressView()
                } else if isRefreshing {
                    ProgressView()
                } else {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityHint("Reloads this list from Bluesky")
                }
            }
        }
        .task {
            await load()
        }
        .confirmationDialog(
            loc("rel.block_confirm"),
            isPresented: $isShowingBlockConfirm,
            titleVisibility: .visible
        ) {
            Button(loc("rel.block"), role: .destructive) {
                guard let actor = actorToBlock,
                      let account = accountStore.activeAccount,
                      let appPassword = accountStore.appPassword(for: account) else { return }
                Task {
                    do {
                        try await blueskyClient.blockActor(
                            did: actor.did,
                            account: account,
                            appPassword: appPassword
                        )
                        actors.removeAll { $0.did == actor.did }
                    } catch {
                        errorMessage = AppError.userMessage(from: error)
                    }
                }
            }
            Button(loc("actions.cancel"), role: .cancel) {}

            Text(loc("rel.block_message"))
        }
        .sheet(isPresented: $isShowingListPicker) {
            if let actor = selectedActorForList,
               let account = accountStore.activeAccount,
               let appPassword = accountStore.appPassword(for: account) {
                ListPickerSheet(actor: actor, account: account, appPassword: appPassword, client: blueskyClient)
                    .environmentObject(accountStore)
                    .environmentObject(blueskyClient)
            }
        }
    }

    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 30

    @ViewBuilder
    private func avatarView(for actor: BlueskyActor) -> some View {
        if let avatarURL = actor.avatarURL {
            AsyncImage(url: avatarURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                avatarPlaceholder(for: actor)
            }
            .frame(width: avatarSize, height: avatarSize)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
        } else {
            avatarPlaceholder(for: actor)
        }
    }

    private func avatarPlaceholder(for actor: BlueskyActor) -> some View {
        Circle()
            .fill(Color.skyPrimary.opacity(0.16))
            .frame(width: avatarSize, height: avatarSize)
            .overlay {
                Text(actor.title.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundStyle(Color.skyPrimary)
            }
    }

    private var csvContent: String {
        let header = "handle,did,display_name,created_at"
        let rows = actors.map { actor in
            [
                actor.handle.csvField,
                actor.did.csvField,
                (actor.displayName ?? "").csvField,
                (actor.createdAt?.ISO8601Format() ?? "").csvField
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private var cacheKey: String? {
        guard let did = accountStore.activeAccount?.did else { return nil }
        return "\(mode.rawValue)_\(did)"
    }

    private func load() async {
        guard let account = accountStore.activeAccount,
              let appPassword = accountStore.appPassword(for: account) else {
            errorMessage = loc("rel.select_account_first")
            isLoading = false
            return
        }

        errorMessage = nil

        let cached: [BlueskyActor]
        if let key = cacheKey {
            cached = RelationshipCache.load(forKey: key)
        } else {
            cached = []
        }

        if !cached.isEmpty {
            actors = cached
            isLoading = false
        } else {
            isLoading = true
        }

        await fetchFromAPI(account: account, appPassword: appPassword)
    }

    private func refresh() async {
        guard let account = accountStore.activeAccount,
              let appPassword = accountStore.appPassword(for: account) else { return }
        isRefreshing = true
        await fetchFromAPI(account: account, appPassword: appPassword)
        isRefreshing = false
    }

    private func fetchFromAPI(account: AppAccount, appPassword: String) async {
        do {
            let did = account.did ?? account.handle
            let result: [BlueskyActor]
            switch mode {
            case .followers:
                result = try await blueskyClient.fetchFollowers(actor: did, account: account, appPassword: appPassword)
            case .following:
                result = try await blueskyClient.fetchFollowing(actor: did, account: account, appPassword: appPassword)
            case .blocking:
                result = try await blueskyClient.fetchBlockedActors(account: account, appPassword: appPassword)
            case .blockedBy:
                result = try await blueskyClient.fetchBlockedByActors(account: account, appPassword: appPassword)
            }
            actors = result
            isLoading = false
            if let key = cacheKey {
                RelationshipCache.save(result, forKey: key)
            }
        } catch {
            if actors.isEmpty {
                errorMessage = AppError.userMessage(from: error)
                isLoading = false
            } else {
                statusMessage = "Loaded \(actors.count) of \(initialCount ?? actors.count). Pull to refresh."
            }
        }
    }
}

struct ListPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let actor: BlueskyActor
    let account: AppAccount
    let appPassword: String
    let client: LiveBlueskyClient
    @State private var lists: [BlueskyList] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView(loc("rel.loading_lists"))
                } else if lists.isEmpty {
                    ContentUnavailableView(loc("rel.no_lists_title"), systemImage: "tray", description: Text(loc("rel.no_lists_desc")))
                } else {
                    List(lists) { list in
                        Button {
                            Task {
                                do {
                                    _ = try await client.addActor(did: actor.did, to: list, account: account, appPassword: appPassword)
                                    dismiss()
                                } catch {
                                }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(list.name)
                                    Text(list.kind.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(Color.skyPrimary)
                            }
                        }
                        .accessibilityHint("Adds \(actor.handle) to \(list.name)")
                    }
                }
            }
            .navigationTitle("\(loc("rel.add_to_list")) \(actor.handle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc("actions.cancel")) { dismiss() }
                    .accessibilityHint("Closes the list picker without adding")
                }
            }
            .task {
                do {
                    lists = try await client.fetchLists(for: account, appPassword: appPassword)
                } catch {}
                isLoading = false
            }
        }
        .presentationDetents([.medium, .large])
    }
}
