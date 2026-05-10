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
                    TextField(loc("note.placeholder").replacingOccurrences(of: "{handle}", with: profile.handle), text: $text)
                        .lineLimit(5...20)
                }
                if !text.isEmpty {
                    Section {
                        Text("\(text.count) characters").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(loc("note.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(loc("note.cancel")) { dismiss() }
                    .accessibilityHint("Discards the note and dismisses") }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("note.save")) {
                        notesStore.setNote(text, for: profile.did)
                        dismiss()
                    }
                    .accessibilityHint("Saves the note for this profile")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
