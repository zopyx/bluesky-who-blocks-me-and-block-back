import Foundation

@MainActor
final class ProfileNotesStore: ObservableObject {
    @Published private(set) var notes: [String: String] = [:]

    private let defaults: UserDefaults
    private let storageKey = "profileNotes"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func note(for did: String) -> String {
        notes[did] ?? ""
    }

    func setNote(_ text: String, for did: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            notes.removeValue(forKey: did)
        } else {
            notes[did] = trimmed
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        notes = decoded
    }
}
