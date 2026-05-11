import SwiftUI

struct ModerationRulesView: View {
    @StateObject private var store = ModerationRuleStore()
    @State private var isCreating = false

    var body: some View {
        List {
            if store.rules.isEmpty {
                ContentUnavailableView(loc("rules.no_rules"), systemImage: "wand.and.rays", description: Text(loc("rules.no_rules_desc")))
            }
            ForEach(store.rules) { rule in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rule.name).font(.headline)
                        Text(loc("rules.rule_format").replacingOccurrences(of: "{trigger}", with: rule.trigger.rawValue).replacingOccurrences(of: "{action}", with: rule.action.rawValue)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { rule.isEnabled }, set: { _ in store.toggle(rule) }))
                        .labelsHidden()
                        .accessibilityHint(rule.isEnabled ? "Disables this moderation rule" : "Enables this moderation rule")
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { store.delete(rule) } label: { Label(loc("actions.delete"), systemImage: "trash") }
                    .accessibilityHint("Permanently deletes this moderation rule")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(loc("rules.title"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button { isCreating = true } label: { Image(systemName: "plus") }.accessibilityHint("Creates a new moderation rule") }
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
                TextField(loc("rules.name_placeholder"), text: $name)
                Picker(loc("rules.trigger"), selection: $trigger) {
                    ForEach(ModerationRule.Trigger.allCases) { t in Text(t.rawValue).tag(t) }
                }
                .accessibilityHint("Choose what condition triggers this rule")
                if trigger == .handleContains || trigger == .hasLabel {
                    TextField(loc("rules.value_placeholder"), text: $triggerValue)
                }
                Picker(loc("rules.action"), selection: $action) {
                    ForEach(ModerationRule.Action.allCases) { a in Text(a.rawValue).tag(a) }
                }
                .accessibilityHint("Choose what action to take when the rule triggers")
            }
            .navigationTitle(loc("rules.new_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(loc("actions.cancel")) { dismiss() }.accessibilityHint("Discards changes and closes the rule editor") }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("actions.save")) {
                        store.save(ModerationRule(name: name, trigger: trigger, triggerValue: triggerValue, action: action))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityHint("Saves this moderation rule")
                }
            }
        }
    }
}

#Preview {
    NavigationStack { ModerationRulesView() }
}
