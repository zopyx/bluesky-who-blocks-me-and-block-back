import SwiftUI
import UniformTypeIdentifiers

struct ListDetailView: View {
    let onListUpdated: ((BlueskyList) -> Void)?

    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var blueskyClient: LiveBlueskyClient
    @EnvironmentObject var workspaceStore: ModerationWorkspaceStore
    @StateObject var viewModel = ListDetailViewModel()
    @State var currentList: BlueskyList
    @State var searchQuery = ""
    @State var memberSearchQuery = ""
    @State var isShowingEditSheet = false
    @State var isShowingBulkRemoveConfirmation = false
    @State var isShowingImportSheet = false
    @State var isShowingImportFilePicker = false
    @State var selectedComparisonListID = ""
    @State var snapshotSummary: ListMembershipSnapshotSummary?
    @State var selectedNewerSnapshotID: UUID?
    @State var selectedOlderSnapshotID: UUID?
    @State var cachedExportFileURL: URL?
    @State var cachedDiffExportFileURL: URL?
    @State private var isShowingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    init(list: BlueskyList, onListUpdated: ((BlueskyList) -> Void)? = nil) {
        self.onListUpdated = onListUpdated
        _currentList = State(initialValue: list)
    }

    var body: some View {
        rootContent
            .navigationTitle(currentList.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: toolbarContent)
            .sheet(isPresented: $isShowingEditSheet, content: editSheetContent)
            .sheet(isPresented: $isShowingImportSheet, content: importSheetContent)
            .sheet(isPresented: importPreviewPresentedBinding, content: importPreviewSheetContent)
            .fileImporter(
                isPresented: $isShowingImportFilePicker,
                allowedContentTypes: [.plainText, .commaSeparatedText]
            ) { result in
                handleImportedFile(result)
            }
            .alert("List", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            }, message: {
                Text(viewModel.errorMessage ?? "")
            })
            .alert(
                viewModel.bulkActionResult?.operation.title ?? "Bulk Update",
                isPresented: bulkResultPresentedBinding
            ) {
                Button("OK") {
                    viewModel.bulkActionResult = nil
                }

                if let account = accountStore.activeAccount,
                   let appPassword = accountStore.appPassword(for: account),
                   let result = viewModel.bulkActionResult,
                   !result.failures.isEmpty {
                    Button("Retry Failed") {
                        Task {
                            await viewModel.retryFailures(
                                from: result,
                                currentList: currentList,
                                comparisonList: comparisonList,
                                account: account,
                                appPassword: appPassword,
                                using: blueskyClient
                            )
                            syncSnapshot()
                        }
                    }
                }
            } message: {
                if let result = viewModel.bulkActionResult {
                    Text(bulkActionMessage(for: result))
                }
            }
            .confirmationDialog(
                "Remove selected members?",
                isPresented: $isShowingBulkRemoveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    if let account = accountStore.activeAccount,
                       let appPassword = accountStore.appPassword(for: account) {
                        Task {
                            await viewModel.bulkRemoveSelectedMembers(
                                account: account,
                                appPassword: appPassword,
                                using: blueskyClient
                            )
                            syncSnapshot()
                        }
                    }
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes \(viewModel.selectedMemberIDs.count) selected member\(viewModel.selectedMemberIDs.count == 1 ? "" : "s") from the list.")
            }
            .confirmationDialog(
                "Delete this list?",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let account = accountStore.activeAccount,
                       let appPassword = accountStore.appPassword(for: account) {
                        Task {
                            do {
                                try await blueskyClient.deleteList(
                                    list: currentList,
                                    account: account,
                                    appPassword: appPassword
                                )
                                onListUpdated?(currentList)
                                dismiss()
                            } catch {
                                viewModel.errorMessage = AppError.userMessage(from: error)
                            }
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes \"\(currentList.name)\" and all its members. This cannot be undone.")
            }
            .onChange(of: viewModel.bulkActionResult) { _, newResult in
                guard let newResult else { return }
                let entry = ModerationOperationLogEntry(
                    title: newResult.operation.title,
                    summary: newResult.summaryText,
                    succeededHandles: newResult.succeededActors.map(\.handle),
                    failedHandles: newResult.failures.map { $0.actor.handle }
                )
                workspaceStore.recordOperation(entry)
            }
    }

    private var rootContent: some View {
        Group {
            if let account = accountStore.activeAccount,
               let appPassword = accountStore.appPassword(for: account) {
                content(account: account, appPassword: appPassword)
            } else {
                ContentUnavailableView(
                    "Missing Credentials",
                    systemImage: "key.slash",
                    description: Text("This account no longer has a saved app password.")
                )
            }
        }
        .onChange(of: memberSearchQuery) { _, newQuery in
            viewModel.updateMemberFilter(newQuery)
        }
        .onChange(of: viewModel.members) { _, _ in
            cachedExportFileURL = nil
        }
        .onChange(of: viewModel.comparisonReport) { _, _ in
            cachedDiffExportFileURL = nil
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isShowingEditSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button(role: .destructive) {
                isShowingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func editSheetContent() -> some View {
        if let account = accountStore.activeAccount,
           let appPassword = accountStore.appPassword(for: account) {
            EditListMetadataSheet(
                list: currentList,
                isSaving: viewModel.isUpdatingMetadata
            ) { title, description in
                Task {
                    if let updatedList = await viewModel.updateMetadata(
                        for: currentList,
                        title: title,
                        description: description,
                        account: account,
                        appPassword: appPassword,
                        using: blueskyClient
                    ) {
                        currentList = updatedList
                        onListUpdated?(updatedList)
                        isShowingEditSheet = false
                    }
                }
            }
        }
    }

    private func importSheetContent() -> some View {
        ImportHandlesSheet { rawInput in
            if let account = accountStore.activeAccount,
               let appPassword = accountStore.appPassword(for: account) {
                Task {
                    await viewModel.prepareImportPreview(
                        from: rawInput,
                        sourceDescription: "Pasted input",
                        account: account,
                        appPassword: appPassword,
                        using: blueskyClient
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func importPreviewSheetContent() -> some View {
        if let importPreview = viewModel.importPreview,
           let account = accountStore.activeAccount,
           let appPassword = accountStore.appPassword(for: account) {
            ImportPreviewSheet(
                preview: importPreview,
                isImporting: viewModel.isImportingHandles || viewModel.isPreparingImportPreview
            ) {
                viewModel.discardImportPreview()
            } importAction: {
                Task {
                    await viewModel.commitImportPreview(
                        to: currentList,
                        account: account,
                        appPassword: appPassword,
                        using: blueskyClient
                    )
                    syncSnapshot()
                }
            }
        }
    }

    @ViewBuilder
    private func content(account: AppAccount, appPassword: String) -> some View {
        List {
            if let batchProgress = viewModel.batchProgress {
                Section("Bulk Operation") {
                    BatchProgressCard(
                        title: batchProgress.title,
                        completedCount: batchProgress.completedCount,
                        totalCount: batchProgress.totalCount,
                        currentHandle: batchProgress.currentHandle
                    )
                }
            }

            ListSearchSection(
                viewModel: viewModel,
                searchQuery: $searchQuery,
                currentList: currentList,
                account: account,
                appPassword: appPassword,
                isShowingImportSheet: $isShowingImportSheet,
                isShowingImportFilePicker: $isShowingImportFilePicker,
                exportFileURL: exportFileURL,
                syncSnapshot: { syncSnapshot() }
            )

            ListMembersSection(
                viewModel: viewModel,
                memberSearchQuery: $memberSearchQuery,
                currentList: currentList,
                account: account,
                appPassword: appPassword,
                isShowingBulkRemoveConfirmation: $isShowingBulkRemoveConfirmation,
                syncSnapshot: { syncSnapshot() }
            )

            ListComparisonSection(
                viewModel: viewModel,
                selectedComparisonListID: $selectedComparisonListID,
                currentList: currentList,
                account: account,
                appPassword: appPassword,
                diffExportFileURL: diffExportFileURL,
                comparisonList: comparisonList,
                syncSnapshot: { syncSnapshot() }
            )

            ListSnapshotSection(
                viewModel: viewModel,
                snapshotSummary: snapshotSummary,
                selectedNewerSnapshotID: $selectedNewerSnapshotID,
                selectedOlderSnapshotID: $selectedOlderSnapshotID,
                snapshotHistory: snapshotHistory,
                selectedSnapshotComparison: selectedSnapshotComparison
            )
        }
        .listStyle(.insetGrouped)
        .task {
            await reloadListContext(account: account, appPassword: appPassword)
        }
        .task(id: searchQuery) {
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }

            await viewModel.search(
                query: searchQuery,
                account: account,
                appPassword: appPassword,
                using: blueskyClient
            )
        }
        .refreshable {
            await reloadListContext(account: account, appPassword: appPassword)
        }
    }

    private var bulkResultPresentedBinding: Binding<Bool> {
        Binding(
            get: { viewModel.bulkActionResult != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.bulkActionResult = nil
                }
            }
        )
    }

    private var importPreviewPresentedBinding: Binding<Bool> {
        Binding(
            get: { viewModel.importPreview != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.discardImportPreview()
                }
            }
        )
    }

}
