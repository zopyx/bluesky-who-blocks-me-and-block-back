import SwiftUI

struct FollowerDiffView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @State private var followers: [BlueskyActor] = []
    @State private var previousFollowers: [BlueskyActor] = []
    @State private var isLoading = false
    @State private var statusMessage: String?

    private var newFollowers: [BlueskyActor] {
        let prev = Set(previousFollowers.map(\.did))
        return followers.filter { !prev.contains($0.did) }
    }

    private var unfollowed: [BlueskyActor] {
        let curr = Set(followers.map(\.did))
        return previousFollowers.filter { !curr.contains($0.did) }
    }

    var body: some View {
        List {
            if isLoading {
                Section { ProgressView("Loading followers...") }
            }

            if !newFollowers.isEmpty {
                Section("New Followers (\(newFollowers.count))") {
                    ForEach(newFollowers) { actor in
                        Label(actor.handle, systemImage: "person.fill.badge.plus").foregroundStyle(.green)
                    }
                }
            }

            if !unfollowed.isEmpty {
                Section("Unfollowed (\(unfollowed.count))") {
                    ForEach(unfollowed) { actor in
                        Label(actor.handle, systemImage: "person.fill.badge.minus").foregroundStyle(.red)
                    }
                }
            }

            if !isLoading && newFollowers.isEmpty && unfollowed.isEmpty && !followers.isEmpty {
                ContentUnavailableView("No Changes", systemImage: "person.3", description: Text("Follower list is unchanged since last check."))
            }

            if let statusMessage {
                Text(statusMessage).font(.caption).foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Follower Changes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh") { Task { await load() } }
                    .disabled(isLoading)
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard let account = accountStore.activeAccount,
              let appPassword = accountStore.appPassword(for: account) else { return }
        isLoading = true
        statusMessage = nil
        let did = account.did ?? account.handle

        let cacheKey = "followers_diff_\(did)"
        previousFollowers = RelationshipCache.load(forKey: cacheKey)

        do {
            followers = try await blueskyClient.fetchFollowers(actor: did, account: account, appPassword: appPassword)
            RelationshipCache.save(followers, forKey: cacheKey)
            statusMessage = previousFollowers.isEmpty ? "Baseline captured. Next refresh will show changes." : nil
        } catch {
            if !previousFollowers.isEmpty { followers = previousFollowers }
            statusMessage = AppError.userMessage(from: error)
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack { FollowerDiffView().environmentObject(AccountStore(preview: true)).environmentObject(PreviewBlueskyClient()) }
}
