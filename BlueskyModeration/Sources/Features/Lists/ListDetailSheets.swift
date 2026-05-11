import SwiftUI

struct ImportHandlesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rawInput = ""
    let importAction: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $rawInput)
                        .frame(minHeight: 180)
                } header: {
                    Text(verbatim: loc("list.import.paste_section"))
                }

                Section {
                    HelpSection(
                        title: loc("list.import.help_title"),
                        bulletPoints: [
                            loc("list.import.help_1"),
                            loc("list.import.help_2"),
                            loc("list.import.help_3"),
                            loc("list.import.help_4"),
                            loc("list.import.help_5")
                        ]
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(loc("list.import.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("actions.cancel")) {
                        dismiss()
                    }
                    .accessibilityHint("Dismisses the import sheet")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("list.import.review")) {
                        importAction(rawInput)
                        dismiss()
                    }
                    .disabled(rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityHint("Reviews the imported handles")
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
                Section {
                    Text(preview.sourceDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(verbatim: loc("list.import_preview.summary_text")
                        .replacingOccurrences(of: "{ready}", with: "\(preview.readyItems.count)")
                        .replacingOccurrences(of: "{already}", with: "\(preview.alreadyPresentItems.count)")
                        .replacingOccurrences(of: "{duplicates}", with: "\(preview.duplicateItems.count)")
                        .replacingOccurrences(of: "{unresolved}", with: "\(preview.unresolvedItems.count)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(verbatim: loc("list.import_preview.skip_note"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(verbatim: loc("list.import_preview.summary"))
                }

                previewSection(loc("list.import_preview.ready"), items: preview.readyItems)
                previewSection(loc("list.import_preview.already"), items: preview.alreadyPresentItems)
                previewSection(loc("list.import_preview.duplicate"), items: preview.duplicateItems)
                previewSection(loc("list.import_preview.unresolved"), items: preview.unresolvedItems)

                if !isImporting {
                    Section {
                        HelpSection(
                            title: loc("list.import_preview.help_title"),
                            bulletPoints: [
                                loc("list.import_preview.help_ready"),
                                loc("list.import_preview.help_already"),
                                loc("list.import_preview.help_duplicate"),
                                loc("list.import_preview.help_unresolved"),
                                loc("list.import_preview.help_write")
                            ]
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle(loc("list.import_preview.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("actions.close")) {
                        dismissAction()
                        dismiss()
                    }
                    .disabled(isImporting)
                    .accessibilityHint("Closes the import preview")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isImporting ? loc("list.import_preview.importing") : loc("list.import_preview.import_button")) {
                        importAction()
                    }
                    .disabled(isImporting || preview.readyItems.isEmpty)
                    .accessibilityHint("Imports the reviewed items")
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
                Section {
                    TextField(loc("list.edit.name_placeholder"), text: $title)
                    TextField(loc("list.edit.desc_placeholder"), text: $description)
                        .lineLimit(3...6)
                } header: {
                    Text(verbatim: loc("list.edit.metadata"))
                }
            }
            .navigationTitle(loc("list.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("actions.cancel")) {
                        dismiss()
                    }
                    .disabled(isSaving)
                    .accessibilityHint("Discards changes and dismisses the edit sheet")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("actions.save")) {
                        saveAction(title, description)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    .accessibilityHint("Saves the updated list metadata")
                }
            }
        }
    }
}
