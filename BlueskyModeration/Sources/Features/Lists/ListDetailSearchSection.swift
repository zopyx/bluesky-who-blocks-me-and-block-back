import SwiftUI

extension ListDetailView {
    struct ListSearchSection: View {
        @ObservedObject var viewModel: ListDetailViewModel
        @Binding var searchQuery: String
        let currentList: BlueskyList
        let account: AppAccount
        let appPassword: String
        @Binding var isShowingImportSheet: Bool
        @Binding var isShowingImportFilePicker: Bool
        let exportFileURL: URL?
        let syncSnapshot: () -> Void

        @EnvironmentObject var accountStore: AccountStore
        @EnvironmentObject var blueskyClient: LiveBlueskyClient
        @EnvironmentObject var workspaceStore: ModerationWorkspaceStore

        var body: some View {
            searchSection
            workflowToolsSection
        }

        @ViewBuilder
        private var searchSection: some View {
            Section("Search Bluesky Users") {
                TextField("Search by handle or name", text: $searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Search Bluesky by handle or name")

                if !viewModel.searchResults.isEmpty || viewModel.hasMoreSearchResults {
                    Text(viewModel.searchResultSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !viewModel.searchResults.isEmpty {
                    bulkAddToolbar
                }

                if viewModel.isSearching {
                    LoadingPanel(message: "Searching Bluesky\u{2026}")
                } else if !searchQuery.isEmpty && searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                    EmptyStatePanel(
                        title: "Keep Typing",
                        message: "Type at least 2 characters to search Bluesky."
                    )
                } else if !viewModel.searchResults.isEmpty {
                    ForEach(viewModel.searchResults) { actor in
                        ActorSearchResultRow(
                            actor: actor,
                            isSelected: viewModel.isSelectedForBulkAdd(actor),
                            isAdding: viewModel.isAdding(actor)
                        ) {
                            viewModel.toggleSearchSelection(for: actor)
                        } addAction: {
                            Task {
                                await viewModel.add(
                                    actor: actor,
                                    to: currentList,
                                    account: account,
                                    appPassword: appPassword,
                                    using: blueskyClient
                                )
                                syncSnapshot()
                            }
                        }
                    }

                    if viewModel.isLoadingMoreSearchResults {
                        HStack {
                            ProgressView()
                            Text("Loading more matches")
                                .foregroundStyle(.secondary)
                        }
                    } else if viewModel.hasMoreSearchResults {
                        Button("Load More Results") {
                            Task {
                                await viewModel.loadMoreSearchResults(
                                    account: account,
                                    appPassword: appPassword,
                                    using: blueskyClient
                                )
                            }
                        }
                        .accessibilityLabel("Load more search results")
                    }
                } else if !searchQuery.isEmpty && !viewModel.isSearching {
                    if let errorMsg = viewModel.searchErrorMessage {
                        ErrorRetryBanner(message: errorMsg) {
                            Task {
                                await viewModel.search(
                                    query: searchQuery,
                                    account: account,
                                    appPassword: appPassword,
                                    using: blueskyClient
                                )
                            }
                        }
                    } else {
                        EmptyStatePanel(
                            title: "No Results",
                            message: "No Bluesky accounts match your search."
                        )
                    }
                }
            }
        }

        private var bulkAddToolbar: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button(viewModel.selectedSearchActorIDs.count == viewModel.searchResults.count && !viewModel.searchResults.isEmpty ? "Clear Search Selection" : "Select All Results") {
                        if viewModel.selectedSearchActorIDs.count == viewModel.searchResults.count && !viewModel.searchResults.isEmpty {
                            viewModel.clearSearchSelection()
                        } else {
                            viewModel.selectAllSearchResults()
                        }
                    }
                    .disabled(viewModel.isPerformingBulkAction)

                    Spacer()

                    if !viewModel.selectedSearchActorIDs.isEmpty {
                        Text("\(viewModel.selectedSearchActorIDs.count) selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    Task {
                        await viewModel.bulkAddSelectedActors(
                            to: currentList,
                            account: account,
                            appPassword: appPassword,
                            using: blueskyClient
                        )
                        syncSnapshot()
                    }
                } label: {
                    Label("Add Selected Results", systemImage: "person.crop.circle.badge.plus")
                }
                .disabled(viewModel.selectedSearchActorIDs.isEmpty || viewModel.isPerformingBulkAction)
            }
        }

        private var workflowToolsSection: some View {
            Section("Workflow Tools") {
                Button {
                    isShowingImportSheet = true
                } label: {
                    Label("Paste Handles or CSV", systemImage: "square.and.pencil")
                }
                .accessibilityLabel("Paste handles or CSV to import")

                Button {
                    isShowingImportFilePicker = true
                } label: {
                    Label("Import Text File", systemImage: "arrow.down.doc")
                }
                .accessibilityLabel("Import from text file")

                if let exportFileURL {
                    ShareLink(item: exportFileURL) {
                        Label("Export Member CSV", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Export members as CSV")
                }
            }
        }
    }
}
