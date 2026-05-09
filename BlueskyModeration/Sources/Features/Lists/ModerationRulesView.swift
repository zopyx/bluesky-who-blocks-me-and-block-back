import SwiftUI

struct ModerationRulesView: View {
    @StateObject private var store = ModerationRuleStore()
    @State private var isCreating = false

    var body: some View {
        List {
            if store.rules.isEmpty {
                ContentUnavailableView("No Rules", systemImage: "wand.and.rays", description: Text("Create rules to automatically moderate accounts."))
            }
            ForEach(store.rules) { rule in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rule.name).font(.headline)
                        Text("If \(rule.trigger.rawValue) → \(rule.action.rawValue)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { rule.isEnabled }, set: { _ in store.toggle(rule) }))
                        .labelsHidden()
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { store.delete(rule) } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Rules")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button { isCreating = true } label: { Image(systemName: "plus") } }
        }
        .sheet(isPresented: $isCreating) { EditRuleView(store: store) }
    }
}

private struct EditRuleView: View {
    @ObservedObject var store: ModerationRuleStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var trigger: ModerationRule.Trigger = .handleContains
    @State private var triggerValue = ""
    @State private var action: ModerationRule.Action = .block

    var body: some View {
        NavigationStack {
            Form {
                TextField("Rule Name", text: $name)
                Picker("Trigger", selection: $trigger) {
                    ForEach(ModerationRule.Trigger.allCases) { t in Text(t.rawValue).tag(t) }
                }
                if trigger == .handleContains || trigger == .hasLabel {
                    TextField("Value", text: $triggerValue)
                }
                Picker("Action", selection: $action) {
                    ForEach(ModerationRule.Action.allCases) { a in Text(a.rawValue).tag(a) }
                }
            }
            .navigationTitle("New Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.save(ModerationRule(name: name, trigger: trigger, triggerValue: triggerValue, action: action))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { ModerationRulesView() }
}
