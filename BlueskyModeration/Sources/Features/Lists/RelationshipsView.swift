import SwiftUI

enum RelationshipMode: String, CaseIterable {
    case followers = "Followers"
    case following = "Following"
}

struct RelationshipsView: View {
    let mode: RelationshipMode
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @State private var actors: [BlueskyActor] = []
    @State private var isLoading = true
    @State private var searchQuery = ""
    @State private var errorMessage: String?
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

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading \(mode.rawValue.lowercased())...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ErrorRetryBanner(message: errorMessage) {
                    Task { await load() }
                }
            } else {
                List {
                    if !actors.isEmpty {
                        Section {
                            TextField("Search \(mode.rawValue.lowercased())", text: $searchQuery)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }

                    if filteredActors.isEmpty && !isLoading {
                        ContentUnavailableView(
                            "No \(mode.rawValue)",
                            systemImage: "person.3",
                            description: Text(searchQuery.isEmpty ? "No accounts found." : "No accounts match your search.")
                        )
                    } else {
                        ForEach(filteredActors) { actor in
                            NavigationLink {
                                BlueskyProfileView(
                                    member: BlueskyListMember(recordURI: "rel:\(actor.did)", actor: actor),
                                    list: nil
                                )
                            } label: {
                                BlueskyActorRow(actor: actor)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    actorToBlock = actor
                                    isShowingBlockConfirm = true
                                } label: {
                                    Label("Block", systemImage: "hand.raised.fill")
                                }

                                Button {
                                    selectedActorForList = actor
                                    isShowingListPicker = true
                                } label: {
                                    Label("Add to List", systemImage: "list.bullet")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    actorToBlock = actor
                                    isShowingBlockConfirm = true
                                } label: {
                                    Label("Block", systemImage: "hand.raised.fill")
                                }
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
        .navigationTitle(mode.rawValue)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isLoading {
                    ProgressView()
                }
            }
        }
        .task {
            await load()
        }
        .confirmationDialog(
            "Block this account?",
            isPresented: $isShowingBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
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
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Blocking prevents interaction and is treated as a destructive moderation action.")
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

    private func load() async {
        guard let account = accountStore.activeAccount,
              let appPassword = accountStore.appPassword(for: account) else {
            errorMessage = "Select an active account first."
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let did = account.did ?? account.handle
            switch mode {
            case .followers:
                actors = try await blueskyClient.fetchFollowers(actor: did, account: account, appPassword: appPassword)
            case .following:
                actors = try await blueskyClient.fetchFollowing(actor: did, account: account, appPassword: appPassword)
            }
        } catch {
            errorMessage = AppError.userMessage(from: error)
        }

        isLoading = false
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
                    ProgressView("Loading lists...")
                } else if lists.isEmpty {
                    ContentUnavailableView("No Lists", systemImage: "tray", description: Text("Create a list first."))
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
                    }
                }
            }
            .navigationTitle("Add \(actor.handle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
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
