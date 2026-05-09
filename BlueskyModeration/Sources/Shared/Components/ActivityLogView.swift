import SwiftUI

struct ActivityLogView: View {
    @EnvironmentObject private var workspaceStore: ModerationWorkspaceStore
    @State private var searchQuery = ""
    @State private var selectedType: String?

    private var types: [String] {
        Array(Set(workspaceStore.operationLog.map(\.title))).sorted()
    }

    private var filtered: [ModerationOperationLogEntry] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return workspaceStore.operationLog.filter { entry in
            if let selectedType, entry.title != selectedType { return false }
            if q.isEmpty { return true }
            return entry.title.lowercased().contains(q) ||
                   entry.summary.lowercased().contains(q) ||
                   entry.succeededHandles.contains(where: { $0.lowercased().contains(q) }) ||
                   entry.failedHandles.contains(where: { $0.lowercased().contains(q) })
        }
    }

    var body: some View {
        List {
            Section {
                TextField("Search operations\u{2026}", text: $searchQuery)
                    .textInputAutocapitalization(.never)
            }

            if !types.isEmpty {
                Section("Filter by Type") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "All", isSelected: selectedType == nil) { selectedType = nil }
                            ForEach(types, id: \.self) { type in
                                FilterChip(title: type, isSelected: selectedType == type) { selectedType = type }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            if filtered.isEmpty {
                ContentUnavailableView("No matches", systemImage: "magnifyingglass", description: Text("Try a different search."))
            } else {
                ForEach(filtered) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(entry.title).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(entry.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(entry.summary).font(.caption).foregroundStyle(.secondary)
                        if !entry.failedHandles.isEmpty {
                            Text("Failed: \(entry.failedHandles.joined(separator: ", "))")
                                .font(.caption2).foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Activity Log")
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : Color.skyPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.skyPrimary : Color.skyPrimary.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ActivityLogView()
            .environmentObject(ModerationWorkspaceStore(preview: true))
    }
}
