import SwiftUI

struct ProfileInspectorView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @EnvironmentObject private var workspaceStore: ModerationWorkspaceStore
    @StateObject private var viewModel = ProfileInspectorViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Lookup") {
                    TextField("Handle or DID", text: $viewModel.query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Search Bluesky by handle or DID")

                    if viewModel.isSearching {
                        HStack {
                            ProgressView()
                            Text("Searching")
                                .foregroundStyle(.secondary)
                        }
                    } else if !viewModel.query.isEmpty && viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                        Text("Type at least 2 characters to search by handle or DID.")
                            .foregroundStyle(.secondary)
                    } else if !viewModel.searchResults.isEmpty {
                        ForEach(viewModel.searchResults) { actor in
                            Button {
                                Task {
                                    await viewModel.inspect(
                                        actor: actor,
                                        account: accountStore.activeAccount,
                                        appPassword: activePassword,
                                        using: blueskyClient
                                    )
                                }
                            } label: {
                                BlueskyActorRow(actor: actor)
                            }
                            .buttonStyle(.plain)
                        }
                    } else if !viewModel.query.isEmpty && !viewModel.isSearching {
                        Text("No matching profiles found.")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task {
                            await viewModel.inspect(
                                account: accountStore.activeAccount,
                                appPassword: activePassword,
                                using: blueskyClient
                            )
                        }
                    } label: {
                        if viewModel.isLoading {
                            HStack {
                                ProgressView()
                                Text("Inspecting")
                            }
                        } else {
                            Label("Inspect Profile", systemImage: "magnifyingglass")
                        }
                    }
                    .disabled(viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                    .accessibilityLabel("Inspect Bluesky profile")

                    Button {
                        workspaceStore.saveProfileSearch(viewModel.query)
                    } label: {
                        Label("Save Search", systemImage: "bookmark")
                    }
                    .disabled(viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Save current search query")

                    if let activeAccount = accountStore.activeAccount {
                        Text("Using \(activeAccount.handle) for authenticated lookup.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Add and select an account first.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    ErrorRetryBanner(message: errorMessage) {
                        viewModel.errorMessage = nil
                        Task {
                            await viewModel.search(
                                account: accountStore.activeAccount,
                                appPassword: activePassword,
                                using: blueskyClient
                            )
                        }
                    }
                }

                if !workspaceStore.savedSearches.isEmpty {
                    Section("Saved Searches") {
                        ForEach(workspaceStore.savedSearches) { search in
                            Button {
                                viewModel.query = search.query
                            } label: {
                                HStack {
                                    Text(search.query)
                                    Spacer()
                                    Image(systemName: "bookmark.fill")
                                        .foregroundStyle(Color.skyPrimary)
                                }
                            }
                            .accessibilityLabel("Load saved search for \(search.query)")
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) {
                                    workspaceStore.deleteSavedSearch(search)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                if !workspaceStore.recentSearches.isEmpty {
                    Section("Recent Searches") {
                        ForEach(workspaceStore.recentSearches) { search in
                            Button {
                                viewModel.query = search.query
                            } label: {
                                HStack {
                                    Text(search.query)
                                    Spacer()
                                    Text(search.usedAt, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityLabel("Load saved search for \(search.query)")
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let inspection = viewModel.inspection {
                    Section("Profile") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(inspection.profile.title)
                                .font(.title3.weight(.semibold))
                            Text(inspection.profile.handle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(inspection.profile.did)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)

                            if let description = inspection.profile.description, !description.isEmpty {
                                Text(description)
                                    .font(.body)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Stats") {
                        LabeledContent("Followers", value: countText(inspection.profile.followersCount))
                        LabeledContent("Following", value: countText(inspection.profile.followsCount))
                        LabeledContent("Posts", value: countText(inspection.profile.postsCount))
                        LabeledContent("Lists", value: countText(inspection.profile.listsCount))
                        LabeledContent("Starter Packs", value: countText(inspection.profile.starterPacksCount))
                    }

                    Section("Moderation Actions") {
                        NavigationLink {
                            BlueskyProfileView(
                                member: BlueskyListMember(
                                    recordURI: "inspection:\(inspection.profile.did)",
                                    actor: BlueskyActor(
                                        did: inspection.profile.did,
                                        handle: inspection.profile.handle,
                                        displayName: inspection.profile.displayName,
                                        avatarURL: inspection.profile.avatarURL
                                    )
                                ),
                                list: nil
                            )
                        } label: {
                            Label("Open Moderation Controls", systemImage: "slider.horizontal.3")
                        }
                        .accessibilityLabel("Open moderation controls for this profile")
                    }

                    if !inspection.profile.labels.isEmpty {
                        Section("Labels") {
                            ForEach(inspection.profile.labels, id: \.self) { label in
                                Text(label)
                            }
                        }
                    }

                    Section("Your Lists") {
                        if inspection.listMemberships.isEmpty {
                            Text("No owned lists available for membership comparison.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(inspection.listMemberships) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name)
                                        Text(item.kind.title)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(item.isMember ? "Member" : "Not In List")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(item.isMember ? .green : .secondary)
                                }
                            }
                        }
                    }

                    Section("Your Starter Packs") {
                        if inspection.starterPackMemberships.isEmpty {
                            Text("No owned starter packs available for membership comparison.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(inspection.starterPackMemberships) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name)
                                        if let joined = item.joinedAllTimeCount {
                                            Text("Joined all-time: \(joined)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(item.isMember ? "Included" : "Not Included")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(item.isMember ? .green : .secondary)
                                }
                            }
                        }
                    }

                    if let profileURL = inspection.profile.profileURL {
                        Section("Open") {
                            Link(destination: profileURL) {
                                Label("Open in Bluesky", systemImage: "arrow.up.right.square")
                            }
                            .accessibilityLabel("Open profile in Bluesky app or website")
                        }
                    }
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .navigationTitle("Profile")
            .task {
                if viewModel.query.isEmpty {
                    viewModel.query = workspaceStore.lastProfileQuery
                }
            }
            .task(id: viewModel.query) {
                do {
                    try await Task.sleep(for: .milliseconds(300))
                } catch {
                    return
                }

                await viewModel.search(
                    account: accountStore.activeAccount,
                    appPassword: activePassword,
                    using: blueskyClient
                )
            }
            .onChange(of: viewModel.query) { _, newValue in
                workspaceStore.lastProfileQuery = newValue
            }
            .onChange(of: viewModel.inspection) { _, newInspection in
                if let newInspection {
                    workspaceStore.noteRecentSearch(newInspection.profile.handle)
                }
            }

        }
    }

    private var activePassword: String? {
        accountStore.activeAccount.flatMap { accountStore.appPassword(for: $0) }
    }

    private func countText(_ value: Int?) -> String {
        if let value {
            return "\(value)"
        }
        return "-"
    }
}

#Preview {
    ProfileInspectorView()
        .environmentObject(AccountStore(preview: true))
        .environmentObject(PreviewBlueskyClient())
        .environmentObject(ModerationWorkspaceStore(preview: true))
}
