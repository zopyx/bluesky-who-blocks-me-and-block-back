import SwiftUI

struct ClearskyListsView: View {
    let entries: [ClearskyListEntry]
    @State private var selectedList: ClearskyListEntry?

    private var regularLists: [ClearskyListEntry] { entries.filter { !$0.isModerationList } }
    private var modLists: [ClearskyListEntry] { entries.filter { $0.isModerationList } }

    var body: some View {
        NavigationStack {
            List {
                if !modLists.isEmpty {
                    Section(loc("lists.moderation_lists")) {
                        ForEach(modLists) { entry in
                            listRow(entry)
                        }
                    }
                }
                if !regularLists.isEmpty {
                    Section(loc("lists.regular_lists")) {
                        ForEach(regularLists) { entry in
                            listRow(entry)
                        }
                    }
                }
            }
            .navigationTitle(loc("lists.lists_on_profile"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedList) { entry in
                ClearskyListDetailView(entry: entry)
            }
        }
    }

    private func listRow(_ entry: ClearskyListEntry) -> some View {
        Button {
            selectedList = entry
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text("\(entry.memberCount)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .font(.caption2)
                    Text(entry.owner.displayName ?? entry.owner.handle)
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

private struct ClearskyListDetailView: View {
    let entry: ClearskyListEntry

    var body: some View {
        NavigationStack {
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
                    LabeledContent(loc("profile.stats.handle"), value: entry.owner.handle)
                    if let displayName = entry.owner.displayName {
                        LabeledContent(loc("profile.stats.display_name"), value: displayName)
                    }
                    LabeledContent(loc("list.details.members"), value: "\(entry.memberCount)")
                }

                Section {
                    LabeledContent(loc("list.details.created"), value: formatDate(entry.createdAt))
                    LabeledContent(loc("list.details.type"), value: entry.isModerationList ? loc("lists.moderation") : loc("lists.regular"))
                }
            }
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
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
}
