import SwiftUI

@MainActor
final class SubscribeToListViewModel: ObservableObject {
    @Published var listURI = ""
    @Published private(set) var fetchedList: BlueskyList?
    @Published private(set) var fetchedMembers: [BlueskyListMember] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isAdding = false
    @Published var errorMessage: String?

    func fetch(account: AppAccount?, appPassword: String?, using client: LiveBlueskyClient) async {
        let trimmed = listURI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a list AT URI or URL."
            return
        }
        guard let account else { errorMessage = "Select an active account first."; return }
        guard let appPassword else { errorMessage = "No saved app password found."; return }

        isLoading = true
        errorMessage = nil
        fetchedList = nil
        fetchedMembers = []

        do {
            let resolvedURI = resolveListURI(trimmed)
            let list = try await client.fetchList(uri: resolvedURI, account: account, appPassword: appPassword)
            guard let list else {
                throw BlueskyAPIError.server("List not found.")
            }
            fetchedList = list
            fetchedMembers = try await client.fetchListMembers(list: list, account: account, appPassword: appPassword)
        } catch {
            errorMessage = AppError.userMessage(from: error)
        }

        isLoading = false
    }

    func addAll(to targetList: BlueskyList, account: AppAccount?, appPassword: String?, using client: LiveBlueskyClient) async {
        guard let account, let appPassword, !fetchedMembers.isEmpty else { return }
        isAdding = true
        errorMessage = nil

        for member in fetchedMembers {
            do {
                _ = try await client.addActor(did: member.actor.did, to: targetList, account: account, appPassword: appPassword)
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                errorMessage = "Failed to add \(member.actor.handle): \(AppError.userMessage(from: error))"
            }
        }

        isAdding = false
    }

    private func resolveListURI(_ input: String) -> String {
        if input.hasPrefix("at://") { return input }
        if input.hasPrefix("https://bsky.app/profile/") {
            let parts = input.split(separator: "/").map(String.init)
            if let did = parts[safe: 4], let rkey = parts[safe: 6] {
                return "at://\(did)/app.bsky.graph.list/\(rkey)"
            }
        }
        return input
    }

    func clear() {
        listURI = ""
        fetchedList = nil
        fetchedMembers = []
        errorMessage = nil
    }
}

struct SubscribeToListView: View {
    let targetList: BlueskyList
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @StateObject private var viewModel = SubscribeToListViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("List AT URI or URL", text: $viewModel.listURI, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(2...4)
                        .font(.body.monospaced())
                } header: {
                    Text("List URI")
                } footer: {
                    Text("Paste the AT URI of a list (e.g. at://did:plc:.../app.bsky.graph.list/rkey) or a bsky.app profile URL.")
                }

                if let list = viewModel.fetchedList {
                    Section("Subscribed List") {
                        LabeledContent("Name", value: list.name)
                        LabeledContent("Members", value: "\(viewModel.fetchedMembers.count)")
                        LabeledContent("Kind", value: list.kind.title)
                    }

                    Section {
                        Button {
                            Task {
                                await viewModel.addAll(to: targetList, account: accountStore.activeAccount, appPassword: accountStore.activeAccount.flatMap { accountStore.appPassword(for: $0) }, using: blueskyClient)
                                if viewModel.errorMessage == nil { dismiss() }
                            }
                        } label: {
                            Label("Add All to \"\(targetList.name)\"", systemImage: "person.crop.circle.badge.plus")
                        }
                        .disabled(viewModel.isAdding)
                        .foregroundStyle(Color.skyPrimary)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    ErrorRetryBanner(message: errorMessage) {
                        viewModel.errorMessage = nil
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Subscribe to List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button("Fetch") {
                            Task { await viewModel.fetch(account: accountStore.activeAccount, appPassword: accountStore.activeAccount.flatMap { accountStore.appPassword(for: $0) }, using: blueskyClient) }
                        }
                        .disabled(viewModel.listURI.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    SubscribeToListView(targetList: BlueskyList(id: "preview-list", name: "My List", description: "A test list", memberCount: nil, kind: .moderation))
        .environmentObject(AccountStore(preview: true))
        .environmentObject(PreviewBlueskyClient())
}
