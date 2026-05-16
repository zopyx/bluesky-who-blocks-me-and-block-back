import SwiftUI

struct ClearskyListsView: View {
    let entries: [ClearskyListEntry]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @EnvironmentObject private var accountStore: AccountStore
    @State private var entryKinds: [String: BlueskyList.Kind] = [:]
    @State private var ownerHandles: [String: String] = [:]

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
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(entry.name)
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
                                if let handle = ownerHandles[entry.url] {
                                    Text(handle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(formatDateRelative(dateString: entry.dateAdded))
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                await loadOwnerHandles()
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

    private func loadOwnerHandles() async {
        let dids = Set(entries.map(\.did))
        guard !dids.isEmpty else { return }
        do {
            let actors = try await LiveBlueskyClient.fetchProfileBatch(identifiers: Array(dids), session: URLSession.shared)
            for actor in actors {
                for entry in entries where entry.did == actor.did {
                    ownerHandles[entry.url] = actor.handle
                }
            }
        } catch {
            AppLogger.performance.error("Failed to fetch owner handles: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func formatDateRelative(dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) ?? {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: dateString)
        }() else { return dateString }

        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if daysSince < 28 {
            let relativeFormatter = RelativeDateTimeFormatter()
            relativeFormatter.unitsStyle = .short
            relativeFormatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage)
            return relativeFormatter.localizedString(for: date, relativeTo: Date())
        }
        return date.formatted(date: .abbreviated, time: .omitted)
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
