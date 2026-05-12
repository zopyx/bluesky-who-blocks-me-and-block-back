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
    @State var importState = ImportState()
    @State var comparisonState = ComparisonState()
    @State var exportState = ExportState()
    @State private var isShowingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    init(list: BlueskyList, onListUpdated: ((BlueskyList) -> Void)? = nil) {
        self.onListUpdated = onListUpdated
        _currentList = State(initialValue: list)
    }

    var body: some View {
        rootContent
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: toolbarContent)
            .sheet(isPresented: $importState.isShowingEditSheet) {
                if let account = accountStore.activeAccount,
                   let appPassword = accountStore.appPassword(for: account)
                {
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
                                importState.isShowingEditSheet = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $importState.isShowingImportSheet, content: importSheetContent)
            .sheet(isPresented: importPreviewPresentedBinding, content: importPreviewSheetContent)
            .fileImporter(
                isPresented: $importState.isShowingImportFilePicker,
                allowedContentTypes: [.plainText, .commaSeparatedText]
            ) { result in
                handleImportedFile(result)
            }
            .alert(loc("list.detail.alert_title"), isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button(loc("actions.ok")) {
                    viewModel.errorMessage = nil
                }
                .accessibilityHint("Dismisses this error message")
            }, message: {
                Text(viewModel.errorMessage ?? "")
            })
            .alert(
                viewModel.bulkActionResult?.operation.title ?? loc("list.detail.bulk_update"),
                isPresented: bulkResultPresentedBinding
            ) {
                Button(loc("actions.ok")) {
                    viewModel.bulkActionResult = nil
                }
                .accessibilityHint("Dismisses the bulk operation result")

                if let account = accountStore.activeAccount,
                   let appPassword = accountStore.appPassword(for: account),
                   let result = viewModel.bulkActionResult,
                   !result.failures.isEmpty
                {
                    Button(loc("list.detail.retry_failed")) {
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
                    .accessibilityHint("Retries the failed operations")
                }
            } message: {
                if let result = viewModel.bulkActionResult {
                    Text(bulkActionMessage(for: result))
                }
            }
            .confirmationDialog(
                loc("list.detail.delete_confirm"),
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(loc("actions.delete"), role: .destructive) {
                    if let account = accountStore.activeAccount,
                       let appPassword = accountStore.appPassword(for: account)
                    {
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
                .accessibilityHint("Deletes this list permanently")
                Button(loc("actions.cancel"), role: .cancel) {}
                    .accessibilityHint("Cancels the deletion")
            } message: {
                Text(verbatim: loc("list.detail.delete_message"))
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
               let appPassword = accountStore.appPassword(for: account)
            {
                content(account: account, appPassword: appPassword)
            } else {
                ContentUnavailableView(
                    loc("list.detail.missing_creds"),
                    systemImage: "key.slash",
                    description: Text(verbatim: loc("list.detail.missing_creds.desc"))
                )
            }
        }
        .onChange(of: memberSearchQuery) { _, newQuery in
            viewModel.updateMemberFilter(newQuery)
        }
        .onChange(of: viewModel.members) { _, _ in
            exportState.cachedExportFileURL = nil
        }
        .onChange(of: viewModel.comparisonReport) { _, _ in
            exportState.cachedDiffExportFileURL = nil
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                importState.isShowingEditSheet = true
            } label: {
                Label { Text(verbatim: loc("list.detail.edit")) } icon: { Image(systemName: "pencil") }
            }
            .accessibilityHint("Opens the edit sheet for this list")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button(role: .destructive) {
                isShowingDeleteConfirmation = true
            } label: {
                Label { Text(verbatim: loc("list.detail.delete")) } icon: { Image(systemName: "trash") }
            }
            .accessibilityHint("Deletes this list permanently")
        }
    }

    private func importSheetContent() -> some View {
        ImportHandlesSheet { rawInput in
            if let account = accountStore.activeAccount,
               let appPassword = accountStore.appPassword(for: account)
            {
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
           let appPassword = accountStore.appPassword(for: account)
        {
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

    private func content(account: AppAccount, appPassword: String) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentList.name)
                        .font(.title2.weight(.bold))
                    if !currentList.description.isEmpty, currentList.description != currentList.name {
                        Text(currentList.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if let batchProgress = viewModel.batchProgress {
                Section {
                    BatchProgressCard(
                        title: batchProgress.title,
                        completedCount: batchProgress.completedCount,
                        totalCount: batchProgress.totalCount,
                        currentHandle: batchProgress.currentHandle
                    )
                } header: {
                    Text(verbatim: loc("list.detail.bulk_operation"))
                }
            }

            ListSearchSection(
                viewModel: viewModel,
                searchQuery: $searchQuery,
                currentList: currentList,
                account: account,
                appPassword: appPassword,
                isShowingImportSheet: $importState.isShowingImportSheet,
                isShowingImportFilePicker: $importState.isShowingImportFilePicker,
                exportFileURL: exportFileURL,
                syncSnapshot: { syncSnapshot() }
            )

            ListMembersSection(
                viewModel: viewModel,
                memberSearchQuery: $memberSearchQuery,
                currentList: currentList,
                account: account,
                appPassword: appPassword,
                syncSnapshot: { syncSnapshot() }
            )

            ListComparisonSection(
                viewModel: viewModel,
                selectedComparisonListID: $comparisonState.selectedComparisonListID,
                currentList: currentList,
                account: account,
                appPassword: appPassword,
                diffExportFileURL: diffExportFileURL,
                comparisonList: comparisonList,
                syncSnapshot: { syncSnapshot() }
            )

            Section {
                LabeledContent(loc("list.detail.members"), value: "\(currentList.memberCount ?? viewModel.members.count)")
                LabeledContent(loc("list.detail.snapshots"), value: "\(snapshotHistory.count)")
                if let first = snapshotHistory.last, let last = snapshotHistory.first {
                    let growth = last.members.count - first.members.count
                    LabeledContent(loc("list.detail.growth"), value: growth == 0 ? loc("list.detail.stable") : (growth > 0 ? "+\(growth)" : "\(growth)"))
                }
            } header: {
                Text(verbatim: loc("list.detail.stats_section"))
            }

            ListSnapshotSection(
                viewModel: viewModel,
                snapshotSummary: comparisonState.snapshotSummary,
                selectedNewerSnapshotID: $comparisonState.selectedNewerSnapshotID,
                selectedOlderSnapshotID: $comparisonState.selectedOlderSnapshotID,
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
