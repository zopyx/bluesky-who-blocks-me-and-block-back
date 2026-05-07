import SwiftUI

struct ListDetailView: View {
    let list: BlueskyList
    let accountSession: AccountSession?

    @State private var items: [ListItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var itemCount: Int = 0

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header Card
                listHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if isLoading && items.isEmpty {
                    LoadingStateView(message: "Loading list items...")
                        .frame(height: 200)
                } else if items.isEmpty && !isLoading {
                    EmptyStateView(
                        icon: "person.2.slash",
                        title: "Empty List",
                        message: "This list doesn't have any members yet."
                    )
                    .frame(height: 300)
                } else {
                    itemsSection
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadListItems()
        }
        .refreshable {
            await loadListItems()
        }
    }

    private var listHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(iconBackgroundColor.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: list.iconName)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(list.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(list.displayPurpose)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(iconColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(iconBackgroundColor.opacity(0.12))
                            .clipShape(Capsule())

                        Text("by @\(list.creatorHandle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            if let description = list.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
            }

            // Stats row
            HStack(spacing: 20) {
                StatItem(count: itemCount, label: "Members")

                if let date = list.indexedAt {
                    StatItem(
                        count: nil,
                        label: date.formatted(.relative(presentation: .named)),
                        icon: "calendar"
                    )
                }

                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Members")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            ForEach(items) { item in
                ListItemRow(item: item)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                if item.id != items.last?.id {
                    Divider()
                        .padding(.leading, 72)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private func loadListItems() async {
        guard let session = accountSession else { return }
        isLoading = true
        errorMessage = nil

        do {
            let response = try await BlueskyAPIService.shared.getList(
                listUri: list.uri,
                accessJwt: session.accessJwt,
                pds: session.pdsEndpoint
            )

            let loadedItems = response.items.map { ListItem(from: $0) }

            await MainActor.run {
                self.items = loadedItems
                self.itemCount = loadedItems.count
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private var iconColor: Color {
        switch list.purpose {
        case .curation: return .blue
        case .moderation: return .orange
        }
    }

    private var iconBackgroundColor: Color {
        switch list.purpose {
        case .curation: return .blue
        case .moderation: return .orange
        }
    }
}

// MARK: - List Item Row

private struct ListItemRow: View {
    let item: ListItem

    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 40)

                Text(String(item.handle.prefix(1).uppercased()))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                if let displayName = item.displayName, !displayName.isEmpty {
                    Text(displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("@\(item.handle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("@\(item.handle)")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Stat Item

private struct StatItem: View {
    let count: Int?
    let label: String
    var icon: String = "person.2"

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let count = count {
                Text("\(count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        ListDetailView(
            list: BlueskyList(
                uri: "at://did:plc:abc/app.bsky.graph.list/1",
                cid: "a",
                name: "Tech Folks",
                description: "A curated list of interesting tech accounts",
                purpose: .curation,
                creatorHandle: "alice.bsky.social",
                creatorDid: "did:plc:abc",
                indexedAt: Date()
            ),
            accountSession: AccountSession(
                accountId: UUID(),
                accessJwt: "test",
                did: "did:plc:abc",
                handle: "alice.bsky.social",
                pdsEndpoint: "https://bsky.social"
            )
        )
    }
}
