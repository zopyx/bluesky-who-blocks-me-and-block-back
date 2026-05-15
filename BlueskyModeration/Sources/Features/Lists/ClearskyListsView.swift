import SwiftUI

struct ClearskyListsView: View {
    let entries: [ClearskyListEntry]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @EnvironmentObject private var accountStore: AccountStore
    @State private var entryKinds: [String: BlueskyList.Kind] = [:]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(entries) { entry in
                        NavigationLink(destination: ListEntryDetailView(entry: entry)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(entry.name)
                                            .font(.headline)
                                            .lineLimit(1)
                                        if entryKinds[entry.url] == .moderation {
                                            Text(loc("lists.moderation"))
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(Color.skyPrimary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.skyPrimary.opacity(0.12), in: Capsule())
                                        }
                                    }
                                    if let desc = entry.description, !desc.isEmpty {
                                        Text(desc)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(loc("lists.lists_on_profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .task {
                await loadKinds()
            }
        }
    }

    private func loadKinds() async {
        guard let account = accountStore.activeAccount,
              let appPassword = accountStore.appPassword(for: account) else { return }
        let batchSize = 10
        let batch = entries.prefix(50)
        for batchStart in stride(from: 0, to: batch.count, by: batchSize) {
            let slice = batch[batchStart ..< min(batchStart + batchSize, batch.count)]
            await withTaskGroup(of: (String, BlueskyList.Kind?).self) { group in
                for entry in slice {
                    group.addTask {
                        guard let uri = atURI(from: entry.url, ownerDID: entry.did) else { return (entry.url, nil) }
                        guard let detail = try? await blueskyClient.fetchList(uri: uri, account: account, appPassword: appPassword) else { return (entry.url, nil) }
                        return (entry.url, detail.kind)
                    }
                }
                for await (url, kind) in group {
                    if let kind { entryKinds[url] = kind }
                }
            }
        }
    }
}

private func atURI(from url: String, ownerDID: String) -> String? {
    let parts = url.split(separator: "/")
    guard parts.count >= 2, let rkey = parts.last else { return nil }
    return "at://\(ownerDID)/app.bsky.graph.list/\(rkey)"
}

private struct ListEntryDetailView: View {
    let entry: ClearskyListEntry
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @EnvironmentObject private var accountStore: AccountStore
    @State private var listDetail: BlueskyList?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let detail = listDetail {
                List {
                    Section {
                        HStack(spacing: 6) {
                            Text(detail.name)
                                .font(.headline)
                            if detail.kind == .moderation {
                                Text(loc("lists.moderation"))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.skyPrimary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.skyPrimary.opacity(0.12), in: Capsule())
                            }
                        }
                        if !detail.description.isEmpty {
                            Text(detail.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section(loc("list.detail.owner")) {
                        Text(entry.did)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        LabeledContent(loc("list.details.members"), value: "\(detail.memberCount ?? 0)")
                        LabeledContent(loc("list.details.created"), value: formatDate(entry.createdDate))
                        LabeledContent(loc("list.details.type"), value: detail.kind == .moderation ? loc("lists.moderation") : loc("lists.regular"))
                    }
                }
            } else if let error = errorMessage {
                ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
            } else {
                List {
                    Section {
                        HStack(spacing: 6) {
                            Text(entry.name)
                                .font(.headline)
                        }
                        if let desc = entry.description, !desc.isEmpty {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Section(loc("list.detail.owner")) {
                        Text(entry.did)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Section {
                        LabeledContent(loc("list.details.created"), value: formatDate(entry.createdDate))
                        LabeledContent(loc("list.details.members"), value: loc("list.detail.not_found"))
                    }
                }
            }
        }
        .navigationTitle(entry.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        guard let account = accountStore.activeAccount,
              let appPassword = accountStore.appPassword(for: account) else { isLoading = false; return }
        guard let uri = atURI(from: entry.url, ownerDID: entry.did) else { isLoading = false; return }
        do {
            let detail = try await blueskyClient.fetchList(uri: uri, account: account, appPassword: appPassword)
            listDetail = detail
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private func formatDate(_ string: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: string) {
        return date.formatted(date: .abbreviated, time: .omitted)
    }
    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: string) {
        return date.formatted(date: .abbreviated, time: .omitted)
    }
    return string
}
