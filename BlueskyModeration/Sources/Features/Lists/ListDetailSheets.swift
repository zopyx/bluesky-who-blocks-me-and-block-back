import SwiftUI

struct ImportHandlesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rawInput = ""
    let importAction: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Paste Handles, DIDs, or Profile URLs") {
                    TextEditor(text: $rawInput)
                        .frame(minHeight: 180)
                }

                Section {
                    HelpSection(
                        title: "What to paste",
                        bulletPoints: [
                            "Bluesky handles: alice.bsky.social",
                            "DIDs: did:plc:abc123",
                            "CSV rows with handles, DIDs, or profile URLs",
                            "Bluesky profile URLs: https://bsky.app/profile/alice.bsky.social",
                            "Duplicate and already-present entries will be detected before import."
                        ]
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Import Handles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Review Import") {
                        importAction(rawInput)
                        dismiss()
                    }
                    .disabled(rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct ImportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let preview: ImportPreview
    let isImporting: Bool
    let dismissAction: () -> Void
    let importAction: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    Text(preview.sourceDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(preview.readyItems.count) ready, \(preview.alreadyPresentItems.count) already present, \(preview.duplicateItems.count) duplicates, \(preview.unresolvedItems.count) unresolved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Already-present accounts will be skipped during import.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                previewSection("Ready to Import", items: preview.readyItems)
                previewSection("Already in List", items: preview.alreadyPresentItems)
                previewSection("Duplicate Entries", items: preview.duplicateItems)
                previewSection("Unresolved", items: preview.unresolvedItems)

                if !isImporting {
                    Section {
                        HelpSection(
                            title: "Understanding classifications",
                            bulletPoints: [
                                "Ready: These accounts will be added to the list.",
                                "Already in List: These accounts are already members and will be skipped.",
                                "Duplicate: Multiple entries in your import resolve to the same account.",
                                "Unresolved: These identifiers could not be found on Bluesky.",
                                "Importing writes to the live Bluesky list immediately."
                            ]
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("Import Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismissAction()
                        dismiss()
                    }
                    .disabled(isImporting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isImporting ? "Importing" : "Import") {
                        importAction()
                    }
                    .disabled(isImporting || preview.readyItems.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func previewSection(_ title: String, items: [ImportPreviewItem]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayHandle)
                        if let actor = item.actor, let displayName = actor.displayName, !displayName.isEmpty {
                            Text(displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let message = item.message {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct EditListMetadataSheet: View {
    @Environment(\.dismiss) private var dismiss
    let list: BlueskyList
    let isSaving: Bool
    let saveAction: (_ title: String, _ description: String) -> Void

    @State private var title: String
    @State private var description: String

    init(
        list: BlueskyList,
        isSaving: Bool,
        saveAction: @escaping (_ title: String, _ description: String) -> Void
    ) {
        self.list = list
        self.isSaving = isSaving
        self.saveAction = saveAction
        _title = State(initialValue: list.name)
        _description = State(initialValue: list.description == list.kind.title ? "" : list.description)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Metadata") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAction(title, description)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }
}
