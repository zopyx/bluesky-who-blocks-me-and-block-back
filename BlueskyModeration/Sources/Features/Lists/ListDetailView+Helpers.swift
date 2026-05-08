import SwiftUI

extension ListDetailView {
    var snapshotHistory: [ListMembershipSnapshot] {
        workspaceStore.snapshotHistory(for: currentList.id)
    }

    var selectedSnapshotComparison: ListMembershipSnapshotSummary? {
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

    var comparisonList: BlueskyList? {
        viewModel.availableLists.first { $0.id == selectedComparisonListID }
    }

    var exportFileURL: URL? {
        if let cached = cachedExportFileURL { return cached }
        let url = fileURL(named: exportFileName, rows: ["handle,did,display_name"] + viewModel.exportRows())
        cachedExportFileURL = url
        return url
    }

    var diffExportFileURL: URL? {
        if let cached = cachedDiffExportFileURL { return cached }
        guard viewModel.comparisonReport != nil else { return nil }
        let url = fileURL(
            named: "\(exportFileName.replacingOccurrences(of: "-members", with: ""))-diff.csv",
            rows: ["bucket,handle,did,display_name"] + viewModel.exportDiffRows()
        )
        cachedDiffExportFileURL = url
        return url
    }

    var exportFileName: String {
        let sanitizedName = currentList.name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return "\(sanitizedName)-members.csv"
    }

    func fileURL(named fileName: String, rows: [String]) -> URL? {
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

    func reloadListContext(account: AppAccount, appPassword: String) async {
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

    func syncSnapshot() {
        snapshotSummary = workspaceStore.captureSnapshot(for: currentList, members: viewModel.members)
        syncSnapshotSelection()
    }

    func syncSnapshotSelection() {
        let history = snapshotHistory
        if selectedNewerSnapshotID == nil {
            selectedNewerSnapshotID = history.first?.id
        }

        if selectedOlderSnapshotID == nil {
            selectedOlderSnapshotID = history.dropFirst().first?.id ?? history.first?.id
        }
    }

    func comparisonSummary(report: ListComparisonReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Compared with \(report.otherList.name)")
                .font(.subheadline.weight(.semibold))

            Text("Overlap: \(report.overlap.count)")
            Text("Only in \(currentList.name): \(report.onlyInCurrent.count)")
            Text("Only in \(report.otherList.name): \(report.onlyInOther.count)")
        }
    }

    func snapshotSummaryView(_ summary: ListMembershipSnapshotSummary) -> some View {
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

    func handleImportedFile(_ result: Result<URL, Error>) {
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

    func bulkActionMessage(for result: ListBulkActionResult) -> String {
        if result.failures.isEmpty {
            return result.summaryText
        }

        let failureDetails = result.failures
            .map { "\($0.actor.handle): \($0.message)" }
            .joined(separator: "\n")

        return "\(result.summaryText)\n\nFailures:\n\(failureDetails)"
    }
}
