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
            Section {
                TextField(loc("list.search.placeholder"), text: $searchQuery)
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
                    LoadingPanel(message: loc("list.search.searching"))
                } else if !searchQuery.isEmpty && searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                    EmptyStatePanel(
                        title: loc("list.search.keep_typing"),
                        message: loc("list.search.keep_typing_desc")
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
                            Text(verbatim: loc("list.search.loading_more"))
                                .foregroundStyle(.secondary)
                        }
                    } else if viewModel.hasMoreSearchResults {
                        Button(loc("list.search.load_more")) {
                            Task {
                                await viewModel.loadMoreSearchResults(
                                    account: account,
                                    appPassword: appPassword,
                                    using: blueskyClient
                                )
                            }
                        }
                        .accessibilityLabel("Load more search results")
                        .accessibilityHint("Fetches more matching accounts from Bluesky")
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
                            title: loc("list.search.no_results"),
                            message: loc("list.search.no_results_desc")
                        )
                    }
                }
            } header: {
                Text(verbatim: loc("list.search.section"))
            }
        }

        private var bulkAddToolbar: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button(viewModel.selectedSearchActorIDs.count == viewModel.searchResults.count && !viewModel.searchResults.isEmpty ? loc("list.search.clear_selection") : loc("list.search.select_all")) {
                        if viewModel.selectedSearchActorIDs.count == viewModel.searchResults.count && !viewModel.searchResults.isEmpty {
                            viewModel.clearSearchSelection()
                        } else {
                            viewModel.selectAllSearchResults()
                        }
                    }
                    .disabled(viewModel.isPerformingBulkAction)
                    .accessibilityHint(viewModel.selectedSearchActorIDs.count == viewModel.searchResults.count && !viewModel.searchResults.isEmpty ? "Deselects all search results" : "Selects every account in the search results")

                    Spacer()

                    if !viewModel.selectedSearchActorIDs.isEmpty {
                        Text(verbatim: loc("list.search.selected").replacingOccurrences(of: "{count}", with: "\(viewModel.selectedSearchActorIDs.count)"))
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
                    Label { Text(verbatim: loc("list.search.add_selected")) } icon: { Image(systemName: "person.crop.circle.badge.plus") }
                }
                .disabled(viewModel.selectedSearchActorIDs.isEmpty || viewModel.isPerformingBulkAction)
                .accessibilityHint("Adds all selected accounts to this list")
            }
        }

        private var workflowToolsSection: some View {
            DisclosureGroup(loc("list.search.tools")) {
                Button {
                    isShowingImportSheet = true
                } label: {
                    Label { Text(verbatim: loc("list.search.paste")) } icon: { Image(systemName: "square.and.pencil") }
                }
                .accessibilityLabel("Paste handles or CSV to import")
                .accessibilityHint("Opens a dialog to paste handles or CSV data for importing")

                Button {
                    isShowingImportFilePicker = true
                } label: {
                    Label { Text(verbatim: loc("list.search.import_file")) } icon: { Image(systemName: "arrow.down.doc") }
                }
                .accessibilityLabel("Import from text file")
                .accessibilityHint("Opens a file picker to select a text file of handles to import")

                if let exportFileURL {
                    ShareLink(item: exportFileURL) {
                        Label { Text(verbatim: loc("list.search.export_csv")) } icon: { Image(systemName: "square.and.arrow.up") }
                    }
                    .accessibilityLabel("Export members as CSV")
                    .accessibilityHint("Shares a CSV file containing all list members")
                }
            }
        }
    }
}
