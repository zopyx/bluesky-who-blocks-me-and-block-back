import SwiftUI
import UniformTypeIdentifiers

struct ListDetailView: View {
    let onListUpdated: ((BlueskyList) -> Void)?

    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var blueskyClient: LiveBlueskyClient
    @EnvironmentObject var workspaceStore: ModerationWorkspaceStore
    @StateObject var viewModel = ListDetailViewModel()
    @StateObject var batchState = ListBatchProgressState()
    @State var currentList: BlueskyList
    @State var searchQuery = ""
    @State var memberSearchQuery = ""
    @State var importState = ImportState()
    @State var comparisonState = ComparisonState()
    @State var exportState = ExportState()
    @State private var isShowingDeleteConfirmation = false
    @State private var shareFileURL: URL?
    @State private var isExporting = false
    @State private var exportProgressMessage: String?
    @State private var exportProgressFraction: Double?
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
            .sheet(isPresented: .init(get: { shareFileURL != nil }, set: { if !$0 { shareFileURL = nil } })) {
                if let url = shareFileURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert(loc("list.detail.alert_title"), isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button(loc("actions.ok")) {
                    viewModel.errorMessage = nil
                }
                .accessibilityHint(loc("list.detail.dismiss_error.hint"))
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
                .accessibilityHint(loc("list.detail.dismiss_bulk.hint"))

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
                    .accessibilityHint(loc("list.detail.retry_failed.hint"))
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
                .accessibilityHint(loc("list.detail.delete_list.hint"))
                Button(loc("actions.cancel"), role: .cancel) {}
                    .accessibilityHint(loc("list.detail.cancel_delete.hint"))
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
            Button(role: .destructive) {
                isShowingDeleteConfirmation = true
            } label: {
                Label { Text(verbatim: loc("list.detail.delete")) } icon: { Image(systemName: "trash") }
            }
            .accessibilityHint(loc("list.detail.delete_list.hint"))
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                importState.isShowingEditSheet = true
            } label: {
                Label { Text(verbatim: loc("list.detail.edit")) } icon: { Image(systemName: "pencil") }
            }
            .accessibilityHint(loc("list.detail.edit_list.hint"))
        }

        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 16) {
                Menu {
                    Button {
                        isExporting = true
                        Task { await exportList(format: .csv) }
                    } label: {
                        Label { Text(verbatim: loc("list.search.export_csv_all")) } icon: { Image(systemName: "square.and.arrow.up") }
                    }

                    Button {
                        isExporting = true
                        Task { await exportList(format: .json) }
                    } label: {
                        Label { Text(verbatim: loc("list.search.export_json_all")) } icon: { Image(systemName: "square.and.arrow.up") }
                    }

                    Button {
                        isExporting = true
                        Task { await exportList(format: .xlsx) }
                    } label: {
                        Label { Text(verbatim: loc("list.export.excel")) } icon: { Image(systemName: "tablecells") }
                    }

                    Button {
                        isExporting = true
                        Task { await exportList(format: .ods) }
                    } label: {
                        Label { Text(verbatim: loc("list.export.ods")) } icon: { Image(systemName: "doc.text") }
                    }
                } label: {
                    if isExporting {
                        HStack(spacing: 6) {
                            if let fraction = exportProgressFraction {
                                ProgressView(value: fraction)
                                    .frame(width: 40)
                                    .scaleEffect(x: 1, y: 0.6)
                            } else {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            if let msg = exportProgressMessage {
                                Text(msg)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(isExporting)

                Button {
                    Task {
                        guard let account = accountStore.activeAccount,
                              let appPassword = accountStore.appPassword(for: account) else { return }
                        await reloadListContext(account: account, appPassword: appPassword)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isExporting || accountStore.activeAccount == nil)
            }
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
                        sourceDescription: loc("list.import.pasted_input"),
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

            BatchProgressSection(batchState: batchState, viewModel: viewModel)

            ListSearchSection(
                viewModel: viewModel,
                batchState: batchState,
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
                batchState: batchState,
                memberSearchQuery: $memberSearchQuery,
                currentList: currentList,
                account: account,
                appPassword: appPassword,
                syncSnapshot: { syncSnapshot() }
            )

            ListComparisonSection(
                viewModel: viewModel,
                batchState: batchState,
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

    private func exportList(format: ExportFormat) async {
        guard let account = accountStore.activeAccount,
              let appPassword = accountStore.appPassword(for: account) else {
            isExporting = false
            return
        }

        exportProgressMessage = "Processing..."
        let members: [BlueskyListMember]
        do {
            members = try await blueskyClient.fetchListMembers(list: currentList, account: account, appPassword: appPassword)
        } catch {
            viewModel.errorMessage = AppError.userMessage(from: error)
            isExporting = false
            exportProgressMessage = nil
            return
        }

        guard !members.isEmpty else {
            isExporting = false
            exportProgressMessage = nil
            return
        }

        let dids = members.map(\.actor.did)
        _ = (dids.count + 24) / 25
        exportProgressFraction = 0
        let stats = (try? await LiveBlueskyClient.fetchProfileStats(dids: dids) { current, total in
            Task { @MainActor in
                exportProgressFraction = Double(current) / Double(total)
                exportProgressMessage = "Processing... \(current)/\(total)"
            }
        }) ?? [:]

        exportProgressMessage = "Processing..."

        let sanitizedName = currentList.name.lowercased().replacingOccurrences(of: " ", with: "-")
        let data: Data

        switch format {
        case .csv:
            let csv = generateCSV(from: members, stats: stats)
            data = Data(csv.utf8)
        case .json:
            data = generateJSON(from: members, stats: stats)
        case .xlsx, .ods:
            let headers = ["handle", "did", "display_name", "followers", "following", "posts", "description"]
            let rows = members.map { member in
                let s = stats[member.actor.did]
                return [
                    member.actor.handle,
                    member.actor.did,
                    member.actor.displayName ?? "",
                    "\(s?.followers ?? 0)",
                    "\(s?.following ?? 0)",
                    "\(s?.posts ?? 0)",
                    s?.description ?? "",
                ]
            }
            if format == .xlsx {
                guard let xlsx = SpreadsheetExport.generateXLSX(headers: headers, rows: rows) else {
                    isExporting = false; exportProgressMessage = nil; return
                }
                data = xlsx
            } else {
                guard let ods = SpreadsheetExport.generateODS(headers: headers, rows: rows) else {
                    isExporting = false; exportProgressMessage = nil; return
                }
                data = ods
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sanitizedName)-full-export.\(format.rawValue)")
        try? data.write(to: url, options: .atomic)
        isExporting = false
        exportProgressMessage = nil
        shareFileURL = url
    }

    private func generateCSV(from members: [BlueskyListMember], stats: [String: (followers: Int, following: Int, posts: Int, description: String)] = [:]) -> String {
        let header = "handle,did,display_name,followers,following,posts,description"
        let rows = members.map { member in
            let s = stats[member.actor.did]
            return [
                member.actor.handle.csvField,
                member.actor.did.csvField,
                (member.actor.displayName ?? "").csvField,
                "\(s?.followers ?? 0)",
                "\(s?.following ?? 0)",
                "\(s?.posts ?? 0)",
                (s?.description ?? "").csvField,
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private func generateJSON(from members: [BlueskyListMember], stats: [String: (followers: Int, following: Int, posts: Int, description: String)] = [:]) -> Data {
        let objects = members.map { member in
            let s = stats[member.actor.did]
            return [
                "handle": member.actor.handle,
                "did": member.actor.did,
                "display_name": member.actor.displayName ?? "",
                "description": s?.description ?? "",
                "followers": s?.followers ?? 0,
                "following": s?.following ?? 0,
                "posts": s?.posts ?? 0,
            ] as [String: Any]
        }
        return (try? JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }
}

extension ListDetailView {
    enum ExportFormat: String, CaseIterable {
        case csv, json, xlsx, ods
    }
}

extension ListDetailView {
    struct BatchProgressSection: View {
        @ObservedObject var batchState: ListBatchProgressState
        let viewModel: ListDetailViewModel

        var body: some View {
            if let batchProgress = batchState.batchProgress {
                Section {
                    BatchProgressCard(
                        title: batchProgress.title,
                        completedCount: batchProgress.completedCount,
                        totalCount: batchProgress.totalCount,
                        currentHandle: batchProgress.currentHandle,
                        onCancel: { batchState.cancelBatch() }
                    )
                } header: {
                    Text(verbatim: loc("list.detail.bulk_operation"))
                }
            }
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
