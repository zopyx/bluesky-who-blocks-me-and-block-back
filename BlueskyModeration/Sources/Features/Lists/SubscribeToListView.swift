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
            errorMessage = loc("list.subscribe.error_uri")
            return
        }
        guard let account else { errorMessage = loc("list.subscribe.error_account"); return }
        guard let appPassword else { errorMessage = loc("list.subscribe.error_password"); return }

        isLoading = true
        errorMessage = nil
        fetchedList = nil
        fetchedMembers = []

        do {
            let resolvedURI = resolveListURI(trimmed)
            let list = try await client.fetchList(uri: resolvedURI, account: account, appPassword: appPassword)
            guard let list else {
                throw BlueskyAPIError.server(loc("list.subscribe.error_not_found"))
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
                    TextField(loc("list.subscribe.uri_placeholder"), text: $viewModel.listURI)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(2...4)
                        .font(.body.monospaced())
                } header: {
                    Text(verbatim: loc("list.subscribe.uri_section"))
                } footer: {
                    Text(verbatim: loc("list.subscribe.uri_footer"))
                }

                if let list = viewModel.fetchedList {
                    Section {
                        LabeledContent(loc("list.subscribe.name"), value: list.name)
                        LabeledContent(loc("list.detail.members"), value: "\(viewModel.fetchedMembers.count)")
                        LabeledContent(loc("list.subscribe.kind"), value: list.kind.title)
                    } header: {
                        Text(verbatim: loc("list.subscribe.subscribed_section"))
                    }

                    Section {
                    Button {
                        Task {
                            await viewModel.addAll(to: targetList, account: accountStore.activeAccount, appPassword: accountStore.activeAccount.flatMap { accountStore.appPassword(for: $0) }, using: blueskyClient)
                            if viewModel.errorMessage == nil { dismiss() }
                        }
                    } label: {
                        Label(loc("list.subscribe.add_all").replacingOccurrences(of: "{list}", with: targetList.name), systemImage: "person.crop.circle.badge.plus")
                    }
                    .disabled(viewModel.isAdding)
                    .foregroundStyle(Color.skyPrimary)
                    .accessibilityHint("Adds all members from the fetched list to the target list")
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    ErrorRetryBanner(message: errorMessage) {
                        viewModel.errorMessage = nil
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(loc("list.subscribe.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button(loc("list.subscribe.fetch")) {
                            Task { await viewModel.fetch(account: accountStore.activeAccount, appPassword: accountStore.activeAccount.flatMap { accountStore.appPassword(for: $0) }, using: blueskyClient) }
                        }
                        .disabled(viewModel.listURI.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityHint("Fetches the list details from the provided URI")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("list.subscribe.cancel")) { dismiss() }
                        .accessibilityHint("Dismisses the subscribe sheet")
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
