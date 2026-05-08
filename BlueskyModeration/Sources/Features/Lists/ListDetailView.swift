import SwiftUI
import UniformTypeIdentifiers

struct ListDetailView: View {
    let onListUpdated: ((BlueskyList) -> Void)?

    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var blueskyClient: LiveBlueskyClient
    @EnvironmentObject private var workspaceStore: ModerationWorkspaceStore
    @StateObject private var viewModel = ListDetailViewModel()
    @State private var currentList: BlueskyList
    @State private var searchQuery = ""
    @State private var memberSearchQuery = ""
    @State private var isShowingEditSheet = false
    @State private var isShowingBulkRemoveConfirmation = false
    @State private var isShowingImportSheet = false
    @State private var isShowingImportFilePicker = false
    @State private var selectedComparisonListID = ""
    @State private var snapshotSummary: ListMembershipSnapshotSummary?
    @State private var selectedNewerSnapshotID: UUID?
    @State private var selectedOlderSnapshotID: UUID?

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
                    VStack(alignment: .leading, spacing: 10) {
                        Text(batchProgress.title)
                            .font(.subheadline.weight(.semibold))
                        ProgressView(value: batchProgress.fractionComplete)
                        Text("\(batchProgress.completedCount) of \(batchProgress.totalCount) complete")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let currentHandle = batchProgress.currentHandle {
                            Text(currentHandle)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Search Bluesky Users") {
                TextField("Search by handle or name", text: $searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !viewModel.searchResults.isEmpty || viewModel.hasMoreSearchResults {
                    Text(viewModel.searchResultSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !viewModel.searchResults.isEmpty {
                    bulkAddToolbar(account: account, appPassword: appPassword)
                }

                if viewModel.isSearching {
                    HStack {
                        ProgressView()
                        Text("Searching")
                            .foregroundStyle(.secondary)
                    }
                } else if !searchQuery.isEmpty && searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                    Text("Type at least 2 characters to search.")
                        .foregroundStyle(.secondary)
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
                    }
                } else if !searchQuery.isEmpty && !viewModel.isSearching {
                    Text("No matching users found.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Find Existing Members") {
                TextField("Filter current members", text: $memberSearchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !viewModel.members.isEmpty {
                    Text(viewModel.loadedMemberSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    bulkRemoveToolbar
                }

                if !memberSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("\(filteredMembers.count) matching members")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Workflow Tools") {
                Button {
                    isShowingImportSheet = true
                } label: {
                    Label("Paste Handles or CSV", systemImage: "square.and.pencil")
                }

                Button {
                    isShowingImportFilePicker = true
                } label: {
                    Label("Import Text File", systemImage: "arrow.down.doc")
                }

                if let exportFileURL {
                    ShareLink(item: exportFileURL) {
                        Label("Export Member CSV", systemImage: "square.and.arrow.up")
                    }
                }
            }

            comparisonSection(account: account, appPassword: appPassword)
            snapshotSection
            operationLogSection

            Section("Members") {
                if viewModel.isLoadingMembers && viewModel.members.isEmpty {
                    HStack {
                        ProgressView()
                        Text("Loading members")
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.members.isEmpty {
                    Text("No members in this list yet.")
                        .foregroundStyle(.secondary)
                } else if filteredMembers.isEmpty {
                    Text("No existing members match this filter.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredMembers) { member in
                        HStack(spacing: 12) {
                            Button {
                                viewModel.toggleMemberSelection(for: member)
                            } label: {
                                Image(systemName: viewModel.isSelectedForBulkRemoval(member) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(viewModel.isSelectedForBulkRemoval(member) ? Color.skyPrimary : Color.secondary.opacity(0.45))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(viewModel.isSelectedForBulkRemoval(member) ? "Deselect \(member.actor.handle)" : "Select \(member.actor.handle)")

                            NavigationLink {
                                BlueskyProfileView(member: member, list: currentList)
                            } label: {
                                BlueskyActorRow(actor: member.actor)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.remove(
                                            member: member,
                                            account: account,
                                            appPassword: appPassword,
                                            using: blueskyClient
                                        )
                                        syncSnapshot()
                                    }
                                } label: {
                                    Label("Remove", systemImage: "person.crop.circle.badge.minus")
                                }
                                .disabled(viewModel.isRemoving(member) || viewModel.isPerformingBulkAction)
                            }
                        }
                        .task {
                            await viewModel.loadMoreMembersIfNeeded(
                                currentMember: member,
                                list: currentList,
                                account: account,
                                appPassword: appPassword,
                                using: blueskyClient
                            )
                        }
                    }

                    if viewModel.isLoadingMoreMembers {
                        HStack {
                            ProgressView()
                            Text("Loading more members")
                                .foregroundStyle(.secondary)
                        }
                    } else if viewModel.hasMoreMembers {
                        Button("Load More Members") {
                            Task {
                                await viewModel.loadMoreMembersIfNeeded(
                                    currentMember: filteredMembers.last,
                                    list: currentList,
                                    account: account,
                                    appPassword: appPassword,
                                    using: blueskyClient
                                )
                            }
                        }
                    }
                }
            }
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

    private var filteredMembers: [BlueskyListMember] {
        viewModel.filteredMembers(matching: memberSearchQuery)
    }

    private var snapshotHistory: [ListMembershipSnapshot] {
        workspaceStore.snapshotHistory(for: currentList.id)
    }

    private var selectedSnapshotComparison: ListMembershipSnapshotSummary? {
        guard let selectedNewerSnapshotID,
              let selectedOlderSnapshotID,
              selectedNewerSnapshotID != selectedOlderSnapshotID else {
            return nil
        }

        return workspaceStore.compareSnapshots(
            listID: currentList.id,
            newerSnapshotID: selectedNewerSnapshotID,
            olderSnapshotID: selectedOlderSnapshotID
        )
    }

    private var bulkRemoveToolbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(viewModel.selectedMemberIDs.count == filteredMembers.count && !filteredMembers.isEmpty ? "Clear Visible Selection" : "Select Visible Members") {
                    if viewModel.selectedMemberIDs.count == filteredMembers.count && !filteredMembers.isEmpty {
                        viewModel.clearMemberSelection()
                    } else {
                        viewModel.selectAllFilteredMembers(matching: memberSearchQuery)
                    }
                }
                .disabled(viewModel.isPerformingBulkAction || filteredMembers.isEmpty)

                Spacer()

                if !viewModel.selectedMemberIDs.isEmpty {
                    Text("\(viewModel.selectedMemberIDs.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button(role: .destructive) {
                isShowingBulkRemoveConfirmation = true
            } label: {
                Label("Remove Selected Members", systemImage: "person.crop.circle.badge.minus")
            }
            .disabled(viewModel.selectedMemberIDs.isEmpty || viewModel.isPerformingBulkAction)
        }
    }

    private func bulkAddToolbar(account: AppAccount, appPassword: String) -> some View {
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

    private func comparisonSection(account: AppAccount, appPassword: String) -> some View {
        Section("Compare and Transfer") {
            if viewModel.isLoadingAvailableLists {
                HStack {
                    ProgressView()
                    Text("Loading your other lists")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.availableLists.isEmpty {
                Text("No other lists are available for comparison or transfer.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Compare With", selection: $selectedComparisonListID) {
                    Text("Select a list").tag("")
                    ForEach(viewModel.availableLists) { list in
                        Text(list.name).tag(list.id)
                    }
                }

                Button {
                    if let comparisonList {
                        Task {
                            await viewModel.compare(
                                currentList: currentList,
                                otherList: comparisonList,
                                account: account,
                                appPassword: appPassword,
                                using: blueskyClient
                            )
                        }
                    }
                } label: {
                    Label("Compare Lists", systemImage: "rectangle.split.3x1")
                }
                .disabled(comparisonList == nil || viewModel.isComparingLists)

                Button {
                    if let comparisonList {
                        Task {
                            await viewModel.transferSelectedMembers(
                                from: currentList,
                                to: comparisonList,
                                move: false,
                                account: account,
                                appPassword: appPassword,
                                using: blueskyClient
                            )
                        }
                    }
                } label: {
                    Label("Copy Selected Members", systemImage: "square.on.square")
                }
                .disabled(comparisonList == nil || viewModel.selectedMemberIDs.isEmpty || viewModel.isPerformingBulkAction)

                Button {
                    if let comparisonList {
                        Task {
                            await viewModel.transferSelectedMembers(
                                from: currentList,
                                to: comparisonList,
                                move: true,
                                account: account,
                                appPassword: appPassword,
                                using: blueskyClient
                            )
                            syncSnapshot()
                        }
                    }
                } label: {
                    Label("Move Selected Members", systemImage: "arrow.right.square")
                }
                .disabled(comparisonList == nil || viewModel.selectedMemberIDs.isEmpty || viewModel.isPerformingBulkAction)

                if let comparisonReport = viewModel.comparisonReport {
                    comparisonSummary(report: comparisonReport)
                    comparisonToolbar(account: account, appPassword: appPassword)

                    ForEach(ComparisonBucket.allCases, id: \.self) { bucket in
                        comparisonBucketSection(bucket)
                    }
                }
            }
        }
    }

    private func comparisonToolbar(account: AppAccount, appPassword: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Menu("Select Diff Bucket") {
                    ForEach(ComparisonBucket.allCases, id: \.self) { bucket in
                        Button(bucket.title) {
                            viewModel.selectComparisonBucket(bucket)
                        }
                    }
                }

                Button("Clear Diff Selection") {
                    viewModel.clearComparisonSelection()
                }
                .disabled(viewModel.selectedComparisonActorDIDs.isEmpty)

                Spacer()

                if !viewModel.selectedComparisonActorDIDs.isEmpty {
                    Text("\(viewModel.selectedComparisonActorDIDs.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task {
                    await viewModel.bulkAddComparisonSelection(
                        to: currentList,
                        account: account,
                        appPassword: appPassword,
                        using: blueskyClient
                    )
                    syncSnapshot()
                }
            } label: {
                Label("Add Selected Diff Accounts Here", systemImage: "arrow.down.left.and.arrow.up.right")
            }
            .disabled(viewModel.selectedComparisonActorDIDs.isEmpty || viewModel.isPerformingBulkAction)

            if let diffExportFileURL {
                ShareLink(item: diffExportFileURL) {
                    Label("Export Diff CSV", systemImage: "square.and.arrow.up")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func comparisonBucketSection(_ bucket: ComparisonBucket) -> some View {
        let members = viewModel.comparisonMembers(for: bucket)

        return Group {
            if !members.isEmpty {
                Section(bucket.title) {
                    ForEach(members) { member in
                        Button {
                            viewModel.toggleComparisonSelection(for: member.actor.did)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: viewModel.selectedComparisonActorDIDs.contains(member.actor.did) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(viewModel.selectedComparisonActorDIDs.contains(member.actor.did) ? Color.skyPrimary : Color.secondary.opacity(0.45))
                                BlueskyActorRow(actor: member.actor)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var snapshotSection: some View {
        Group {
            if let snapshotSummary {
                Section("Snapshot History") {
                    if let previousCaptureDate = snapshotSummary.previousCaptureDate {
                        Text("Previous snapshot: \(previousCaptureDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Current snapshot: \(snapshotSummary.currentCaptureDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    snapshotSummaryView(snapshotSummary)

                    if snapshotHistory.count > 1 {
                        Picker("Newer Snapshot", selection: $selectedNewerSnapshotID) {
                            ForEach(snapshotHistory, id: \.id) { snapshot in
                                Text(snapshot.capturedAt.formatted(date: .abbreviated, time: .shortened))
                                    .tag(Optional(snapshot.id))
                            }
                        }

                        Picker("Older Snapshot", selection: $selectedOlderSnapshotID) {
                            ForEach(snapshotHistory, id: \.id) { snapshot in
                                Text(snapshot.capturedAt.formatted(date: .abbreviated, time: .shortened))
                                    .tag(Optional(snapshot.id))
                            }
                        }

                        if let selectedSnapshotComparison {
                            Divider()
                            Text("What Changed Since")
                                .font(.subheadline.weight(.semibold))
                            snapshotSummaryView(selectedSnapshotComparison)
                        }
                    }
                }
            }
        }
    }

    private var operationLogSection: some View {
        Group {
            if !workspaceStore.operationLog.isEmpty {
                Section("Recent Operations") {
                    ForEach(workspaceStore.operationLog.prefix(5)) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.title)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(entry.createdAt, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.summary)
                            if !entry.failedHandles.isEmpty {
                                Text("Failed: \(entry.failedHandles.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
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

    private func bulkActionMessage(for result: ListBulkActionResult) -> String {
        if result.failures.isEmpty {
            return result.summaryText
        }

        let failureDetails = result.failures
            .map { "\($0.actor.handle): \($0.message)" }
            .joined(separator: "\n")

        return "\(result.summaryText)\n\nFailures:\n\(failureDetails)"
    }

    private var comparisonList: BlueskyList? {
        viewModel.availableLists.first { $0.id == selectedComparisonListID }
    }

    private var exportFileURL: URL? {
        fileURL(named: exportFileName, rows: ["handle,did,display_name"] + viewModel.exportRows())
    }

    private var diffExportFileURL: URL? {
        guard viewModel.comparisonReport != nil else { return nil }
        return fileURL(
            named: "\(exportFileName.replacingOccurrences(of: "-members", with: ""))-diff.csv",
            rows: ["bucket,handle,did,display_name"] + viewModel.exportDiffRows()
        )
    }

    private var exportFileName: String {
        let sanitizedName = currentList.name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return "\(sanitizedName)-members.csv"
    }

    private func fileURL(named fileName: String, rows: [String]) -> URL? {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
        let content = rows.joined(separator: "\n")

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }

    private func reloadListContext(account: AppAccount, appPassword: String) async {
        async let membersTask: Void = viewModel.loadMembers(
            for: currentList,
            account: account,
            appPassword: appPassword,
            using: blueskyClient
        )
        async let listsTask: Void = viewModel.loadAvailableLists(
            excluding: currentList,
            account: account,
            appPassword: appPassword,
            using: blueskyClient
        )

        _ = await (membersTask, listsTask)

        if selectedComparisonListID.isEmpty {
            selectedComparisonListID = viewModel.availableLists.first?.id ?? ""
        }
        syncSnapshot()
        syncSnapshotSelection()
    }

    private func syncSnapshot() {
        snapshotSummary = workspaceStore.captureSnapshot(for: currentList, members: viewModel.members)
        syncSnapshotSelection()
    }

    private func syncSnapshotSelection() {
        let history = snapshotHistory
        if selectedNewerSnapshotID == nil {
            selectedNewerSnapshotID = history.first?.id
        }

        if selectedOlderSnapshotID == nil {
            selectedOlderSnapshotID = history.dropFirst().first?.id ?? history.first?.id
        }
    }

    private func comparisonSummary(report: ListComparisonReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Compared with \(report.otherList.name)")
                .font(.subheadline.weight(.semibold))

            Text("Overlap: \(report.overlap.count)")
            Text("Only in \(currentList.name): \(report.onlyInCurrent.count)")
            Text("Only in \(report.otherList.name): \(report.onlyInOther.count)")
        }
    }

    private func snapshotSummaryView(_ summary: ListMembershipSnapshotSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if summary.hasChanges {
                if !summary.addedMembers.isEmpty {
                    Text("Added: \(summary.addedMembers.map(\.handle).joined(separator: ", "))")
                }

                if !summary.removedMembers.isEmpty {
                    Text("Removed: \(summary.removedMembers.map(\.handle).joined(separator: ", "))")
                }
            } else {
                Text("No membership changes in this comparison.")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private func handleImportedFile(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                if let account = accountStore.activeAccount,
                   let appPassword = accountStore.appPassword(for: account) {
                    Task {
                        await viewModel.prepareImportPreview(
                            from: content,
                            sourceDescription: url.lastPathComponent,
                            account: account,
                            appPassword: appPassword,
                            using: blueskyClient
                        )
                    }
                }
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        case .failure(let error):
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ListDetailView(
            list: BlueskyList(
                id: "at://did:plc:preview/app.bsky.graph.list/123",
                name: "Trusted Sources",
                description: "Accounts curated for signal over noise.",
                memberCount: 67,
                kind: .regular
            )
        )
    }
    .environmentObject(AccountStore(preview: true))
    .environmentObject(PreviewBlueskyClient())
    .environmentObject(ModerationWorkspaceStore(preview: true))
}

private struct ImportHandlesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rawInput = ""
    let importAction: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Paste Handles, DIDs, or Profile URLs") {
                    TextEditor(text: $rawInput)
                        .frame(minHeight: 180)
                }

                Section {
                    Text("CSV, newline-separated, profile URLs, and plain handles are accepted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Import Handles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Review Import") {
                        importAction(rawInput)
                        dismiss()
                    }
                    .disabled(rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct ImportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let preview: ImportPreview
    let isImporting: Bool
    let dismissAction: () -> Void
    let importAction: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    Text(preview.sourceDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(preview.readyItems.count) ready, \(preview.alreadyPresentItems.count) already present, \(preview.duplicateItems.count) duplicates, \(preview.unresolvedItems.count) unresolved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Already-present accounts will be skipped during import.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                previewSection("Ready to Import", items: preview.readyItems)
                previewSection("Already in List", items: preview.alreadyPresentItems)
                previewSection("Duplicate Entries", items: preview.duplicateItems)
                previewSection("Unresolved", items: preview.unresolvedItems)
            }
            .navigationTitle("Import Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismissAction()
                        dismiss()
                    }
                    .disabled(isImporting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isImporting ? "Importing" : "Import") {
                        importAction()
                    }
                    .disabled(isImporting || preview.readyItems.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func previewSection(_ title: String, items: [ImportPreviewItem]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayHandle)
                        if let actor = item.actor, let displayName = actor.displayName, !displayName.isEmpty {
                            Text(displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let message = item.message {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct EditListMetadataSheet: View {
    @Environment(\.dismiss) private var dismiss
    let list: BlueskyList
    let isSaving: Bool
    let saveAction: (_ title: String, _ description: String) -> Void

    @State private var title: String
    @State private var description: String

    init(
        list: BlueskyList,
        isSaving: Bool,
        saveAction: @escaping (_ title: String, _ description: String) -> Void
    ) {
        self.list = list
        self.isSaving = isSaving
        self.saveAction = saveAction
        _title = State(initialValue: list.name)
        _description = State(initialValue: list.description == list.kind.title ? "" : list.description)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Metadata") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAction(title, description)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }
}
