import SwiftUI

struct ProfileInspectorView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @StateObject private var viewModel = ProfileInspectorViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Lookup") {
                    TextField("Handle or DID", text: $viewModel.query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

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
                        }
                    }
                }
            }
            .navigationTitle("Profile")
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
            .alert("Profile", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            }, message: {
                Text(viewModel.errorMessage ?? "")
            })
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
}
