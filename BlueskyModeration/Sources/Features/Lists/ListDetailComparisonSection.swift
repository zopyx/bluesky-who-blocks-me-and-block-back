import SwiftUI

extension ListDetailView {
    struct ListComparisonSection: View {
        @ObservedObject var viewModel: ListDetailViewModel
        @Binding var selectedComparisonListID: String
        let currentList: BlueskyList
        let account: AppAccount
        let appPassword: String
        let diffExportFileURL: URL?
        let comparisonList: BlueskyList?
        let syncSnapshot: () -> Void

        @EnvironmentObject var accountStore: AccountStore
        @EnvironmentObject var blueskyClient: LiveBlueskyClient
        @EnvironmentObject var workspaceStore: ModerationWorkspaceStore

        @State private var showingCompareHelp = false

        var body: some View {
            DisclosureGroup {
                if viewModel.isLoadingAvailableLists {
                    LoadingPanel(message: "Loading your other lists\u{2026}")
                } else if viewModel.availableLists.isEmpty {
                    EmptyStatePanel(
                        title: "No Other Lists",
                        message: "Create additional lists to use comparison and transfer tools."
                    )
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
                        comparisonToolbar

                        ForEach(ComparisonBucket.allCases, id: \.self) { bucket in
                            comparisonBucketSection(bucket)
                        }
                    }
                }
            } label: {
                HStack {
                    Text("Compare and Transfer")
                    Spacer()
                    Button {
                        showingCompareHelp = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(Color.skyPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showingCompareHelp) {
                NavigationStack {
                    List {
                        HelpSection(
                            title: "Understanding the buckets",
                            bulletPoints: [
                                "Overlap: members present in both lists.",
                                "Only in current list: members unique to this list.",
                                "Only in comparison list: members in the other list but not this one.",
                                "Copy adds selected members from the compared list to this list without affecting the source.",
                                "Move transfers selected members from this list to the other, removing them from this list."
                            ]
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                    .navigationTitle("Compare & Transfer Help")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingCompareHelp = false }
                        }
                    }
                }
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

        private var comparisonToolbar: some View {
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
                            .accessibilityLabel(
                                viewModel.selectedComparisonActorDIDs.contains(member.actor.did)
                                    ? "Deselect \(member.actor.handle)"
                                    : "Select \(member.actor.handle)"
                            )
                        }
                    }
                }
            }
        }
    }
}
