import SwiftUI

struct CreateListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var selectedKind: BlueskyList.Kind = .moderation
    let onCreate: (String, String, BlueskyList.Kind) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("List Name", text: $name)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Type") {
                    Picker("Kind", selection: $selectedKind) {
                        ForEach(BlueskyList.Kind.allCases, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section {
                    Text("Moderation lists are used for blocking and muting. Regular lists are for curation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Create List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name.trimmingCharacters(in: .whitespacesAndNewlines), description.trimmingCharacters(in: .whitespacesAndNewlines), selectedKind)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
