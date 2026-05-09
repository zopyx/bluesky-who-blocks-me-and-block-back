import SwiftUI

struct ActionPresetsView: View {
    @StateObject private var store = ActionPresetStore()
    @State private var isCreating = false

    var body: some View {
        List {
            if store.presets.isEmpty {
                ContentUnavailableView("No Presets", systemImage: "square.2.layers.3d", description: Text("Create reusable action sets for common moderation tasks."))
            }

            ForEach(store.presets) { preset in
                VStack(alignment: .leading, spacing: 6) {
                    Text(preset.name).font(.headline)
                    HStack(spacing: 4) {
                        if preset.shouldBlock { Tag("Block", color: .red) }
                        if preset.shouldMute { Tag("Mute", color: .orange) }
                        if preset.shouldReport { Tag("Report", color: .purple) }
                        if let list = preset.targetListName { Tag("Add to \(list)", color: .blue) }
                    }
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { store.delete(preset) } label: { Label("Delete", systemImage: "trash") }
                }
                .swipeActions(edge: .leading) {
                    Button { store.duplicate(preset) } label: { Label("Duplicate", systemImage: "doc.on.doc") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Action Presets")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isCreating = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $isCreating) {
            EditActionPresetView(store: store)
        }
    }
}

private struct Tag: View {
    let text: String
    let color: Color
    init(_ text: String, color: Color) { self.text = text; self.color = color }
    var body: some View {
        Text(text).font(.caption2.weight(.semibold))
            .foregroundStyle(color).padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct EditActionPresetView: View {
    @ObservedObject var store: ActionPresetStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var shouldBlock = false
    @State private var shouldMute = false
    @State private var shouldReport = false
    @State private var targetListName = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Preset Name", text: $name)
                Section("Actions") {
                    Toggle("Block", isOn: $shouldBlock)
                    Toggle("Mute", isOn: $shouldMute)
                    Toggle("Report", isOn: $shouldReport)
                }
                Section("Add to List (optional)") {
                    TextField("List name", text: $targetListName)
                }
            }
            .navigationTitle("New Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.save(ActionPreset(name: name, shouldBlock: shouldBlock, shouldMute: shouldMute, shouldReport: shouldReport, targetListName: targetListName.isEmpty ? nil : targetListName))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { ActionPresetsView() }
}
