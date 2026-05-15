import SwiftUI

struct ClearskyListsView: View {
    let entries: [ClearskyListEntry]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @EnvironmentObject private var accountStore: AccountStore
    @State private var entryKinds: [String: BlueskyList.Kind] = [:]

    private var sortedEntries: [ClearskyListEntry] {
        entries.sorted { a, b in
            date(from: a.createdDate) > date(from: b.createdDate)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(sortedEntries) { entry in
                        VStack(alignment: .leading, spacing: 8) {
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
                                    .lineLimit(2)
                            }
                            HStack {
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = entry.did
                                } label: {
                                    Label(entry.did, systemImage: "doc.on.doc")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            HStack {
                                Spacer()
                                Label(formatDate(entry.createdDate), systemImage: "calendar")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 6)
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

    private func date(from string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) { return date }
        return .distantPast
    }
}

private func atURI(from url: String, ownerDID: String) -> String? {
    let parts = url.split(separator: "/")
    guard parts.count >= 2, let rkey = parts.last else { return nil }
    return "at://\(ownerDID)/app.bsky.graph.list/\(rkey)"
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
