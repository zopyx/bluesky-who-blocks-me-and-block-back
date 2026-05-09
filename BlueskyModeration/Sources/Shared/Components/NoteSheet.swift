import SwiftUI

struct NoteSheet: View {
    let profile: BlueskyProfile
    @ObservedObject var notesStore: ProfileNotesStore
    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(profile: BlueskyProfile, notesStore: ProfileNotesStore) {
        self.profile = profile
        self.notesStore = notesStore
        _text = State(initialValue: notesStore.note(for: profile.did))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Add a private note about \(profile.handle)", text: $text, axis: .vertical)
                        .lineLimit(5...20)
                }
                if !text.isEmpty {
                    Section {
                        Text("\(text.count) characters").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Profile Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        notesStore.setNote(text, for: profile.did)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
