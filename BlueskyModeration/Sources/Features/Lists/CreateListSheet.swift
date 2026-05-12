import SwiftUI

struct CreateListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    let kind: BlueskyList.Kind
    let onCreate: (String, String, BlueskyList.Kind) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(loc("list.create.name_placeholder"), text: $name)
                    TextField(loc("list.create.desc_placeholder"), text: $description)
                        .lineLimit(3 ... 6)
                } header: {
                    Text(verbatim: loc("list.create.details"))
                }
            }
            .navigationTitle(kind == .moderation ? loc("list.create.moderation_title") : loc("list.create.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("list.create.cancel")) { dismiss() }
                        .accessibilityHint("Discards and dismisses the create list sheet")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("list.create.create")) {
                        onCreate(name.trimmingCharacters(in: .whitespacesAndNewlines), description.trimmingCharacters(in: .whitespacesAndNewlines), kind)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityHint("Creates the new list")
                }
            }
        }
    }
}
