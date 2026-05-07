import SwiftUI

struct BlueskyProfileView: View {
    let member: BlueskyListMember
    let list: BlueskyList?

    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @StateObject private var viewModel = BlueskyProfileViewModel()

    var body: some View {
        Group {
            if let account = accountStore.activeAccount,
               let appPassword = accountStore.appPassword(for: account) {
                content(account: account, appPassword: appPassword)
            } else {
                ContentUnavailableView(
                    "Missing Credentials",
                    systemImage: "key.slash",
                    description: Text("This account no longer has a saved app password.")
                )
            }
        }
        .navigationTitle(member.actor.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Profile", isPresented: .constant(viewModel.errorMessage != nil), actions: {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        }, message: {
            Text(viewModel.errorMessage ?? "")
        })
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

                Section("Stats") {
                    LabeledContent("Followers", value: statText(profile.followersCount))
                    LabeledContent("Following", value: statText(profile.followsCount))
                    LabeledContent("Posts", value: statText(profile.postsCount))
                }

                Section("Actions") {
                    if let profileURL = profile.profileURL {
                        Link(destination: profileURL) {
                            Label("Open in Bluesky", systemImage: "arrow.up.right.square")
                        }
                    }

                    if let list {
                        Label("Member of \(list.name)", systemImage: "person.2.badge.gearshape")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if viewModel.isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("Loading profile")
                            .foregroundStyle(.secondary)
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
