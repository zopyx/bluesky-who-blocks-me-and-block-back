import SwiftUI

struct CreateListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var isShowingTemplates = false
    let kind: BlueskyList.Kind
    let onCreate: (String, String, BlueskyList.Kind) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("List Name", text: $name)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Button("Choose from Templates") { isShowingTemplates = true }
                        .foregroundStyle(Color.skyPrimary)
                }
            }
            .navigationTitle(kind == .moderation ? "Create Moderation List" : "Create List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name.trimmingCharacters(in: .whitespacesAndNewlines), description.trimmingCharacters(in: .whitespacesAndNewlines), kind)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $isShowingTemplates) {
                NavigationStack {
                    ListTemplatesView { template in
                        name = template.name
                        onCreate(template.name, template.description, kind)
                        dismiss()
                    }
                    .environmentObject(AccountStore(preview: true))
                    .environmentObject(PreviewBlueskyClient())
                }
            }
        }
    }
}
