import SwiftUI

struct ClearskyListsView: View {
    let entries: [ClearskyListEntry]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(entries) { entry in
                        NavigationLink(destination: ListEntryDetailView(entry: entry)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.name)
                                        .font(.headline)
                                        .lineLimit(1)
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
        }
    }
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
                        LabeledContent(loc("list.name"), value: detail.name)
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
                        LabeledContent(loc("list.name"), value: entry.name)
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
        guard !entry.url.isEmpty else { isLoading = false; return }
        let parts = entry.url.split(separator: "/")
        guard parts.count >= 2, let rkey = parts.last else { isLoading = false; return }
        let did = entry.did
        let uri = "at://\(did)/app.bsky.graph.list/\(rkey)"
        do {
            guard let account = accountStore.activeAccount,
                  let appPassword = accountStore.appPassword(for: account) else { isLoading = false; return }
            let detail = try await blueskyClient.fetchList(uri: uri, account: account, appPassword: appPassword)
            listDetail = detail
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
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
}
