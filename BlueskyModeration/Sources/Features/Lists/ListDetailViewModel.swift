import Foundation

struct ListBulkActionResult: Identifiable, Equatable {
    enum Operation: Equatable {
        case add
        case remove
        case copy
        case move
        case `import`

        var title: String {
            switch self {
            case .add:
                "Bulk Add"
            case .remove:
                "Bulk Remove"
            case .copy:
                "Copy Members"
            case .move:
                "Move Members"
            case .import:
                "Import Handles"
            }
        }

        var pastTenseVerb: String {
            switch self {
            case .add:
                "added"
            case .remove:
                "removed"
            case .copy:
                "copied"
            case .move:
                "moved"
            case .import:
                "imported"
            }
        }
    }

    struct Failure: Identifiable, Equatable {
        let actor: BlueskyActor
        let message: String

        var id: String { actor.id }
    }

    let operation: Operation
    let succeededActors: [BlueskyActor]
    let failures: [Failure]

    var id: String {
        "\(operation.title)-\(succeededActors.count)-\(failures.count)"
    }

    var summaryText: String {
        let successCount = succeededActors.count
        let failureCount = failures.count

        if failureCount == 0 {
            return "\(successCount) account\(successCount == 1 ? "" : "s") \(operation.pastTenseVerb)."
        }

        if successCount == 0 {
            return "No accounts were \(operation.pastTenseVerb)."
        }

        return "\(successCount) account\(successCount == 1 ? "" : "s") \(operation.pastTenseVerb), \(failureCount) failed."
    }
}

struct ListComparisonReport {
    let otherList: BlueskyList
    let overlap: [BlueskyListMember]
    let onlyInCurrent: [BlueskyListMember]
    let onlyInOther: [BlueskyListMember]
}

struct BatchProgress: Equatable {
    let title: String
    let completedCount: Int
    let totalCount: Int
    let currentHandle: String?

    var fractionComplete: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
}

struct ImportPreviewItem: Identifiable, Hashable {
    enum Classification: String {
        case ready
        case alreadyPresent
        case duplicate
        case unresolved

        var title: String {
            switch self {
            case .ready:
                "Ready to Import"
            case .alreadyPresent:
                "Already in List"
            case .duplicate:
                "Duplicate"
            case .unresolved:
                "Unresolved"
            }
        }
    }

    let token: String
    let actor: BlueskyActor?
    let classification: Classification
    let message: String?

    var id: String {
        let actorKey = actor?.did ?? token
        return "\(classification.rawValue)-\(actorKey)-\(token)"
    }

    var displayHandle: String {
        actor?.handle ?? token
    }
}

struct ImportPreview: Equatable {
    let sourceDescription: String
    let items: [ImportPreviewItem]

    var readyItems: [ImportPreviewItem] {
        items.filter { $0.classification == .ready }
    }

    var alreadyPresentItems: [ImportPreviewItem] {
        items.filter { $0.classification == .alreadyPresent }
    }

    var duplicateItems: [ImportPreviewItem] {
        items.filter { $0.classification == .duplicate }
    }

    var unresolvedItems: [ImportPreviewItem] {
        items.filter { $0.classification == .unresolved }
    }
}

enum ComparisonBucket: String, CaseIterable {
    case overlap
    case onlyInCurrent
    case onlyInOther

    var title: String {
        switch self {
        case .overlap:
            "Shared"
        case .onlyInCurrent:
            "Only Here"
        case .onlyInOther:
            "Only There"
        }
    }
}

@MainActor
final class ListDetailViewModel: ObservableObject {
    @Published private(set) var members: [BlueskyListMember] = []
    @Published private(set) var searchResults: [BlueskyActor] = []
    @Published private(set) var availableLists: [BlueskyList] = []
    @Published private(set) var comparisonReport: ListComparisonReport?
    @Published private(set) var importPreview: ImportPreview?
    @Published private(set) var isLoadingMembers = false
    @Published private(set) var isLoadingMoreMembers = false
    @Published private(set) var hasMoreMembers = false
    @Published private(set) var isLoadingAvailableLists = false
    @Published private(set) var isSearching = false
    @Published private(set) var isLoadingMoreSearchResults = false
    @Published private(set) var hasMoreSearchResults = false
    @Published private(set) var isComparingLists = false
    @Published private(set) var isPreparingImportPreview = false
    @Published private(set) var isImportingHandles = false
    @Published private(set) var isUpdatingMetadata = false
    @Published private(set) var isPerformingBulkAction = false
    @Published private(set) var batchProgress: BatchProgress?
    @Published private(set) var addingActorIDs: Set<String> = []
    @Published private(set) var removingMemberIDs: Set<String> = []
    @Published var selectedSearchActorIDs: Set<String> = []
    @Published var selectedMemberIDs: Set<String> = []
    @Published var selectedComparisonActorDIDs: Set<String> = []
    @Published var bulkActionResult: ListBulkActionResult?
    @Published var errorMessage: String?

    private var memberCursor: String?
    private var searchCursor: String?
    private var lastSearchQuery = ""

    var loadedMemberSummary: String {
        if hasMoreMembers {
            return "Loaded \(members.count) members so far."
        }

        return "\(members.count) member\(members.count == 1 ? "" : "s") loaded."
    }

    var searchResultSummary: String {
        if hasMoreSearchResults {
            return "Showing \(searchResults.count) matches so far."
        }

        return "\(searchResults.count) matching account\(searchResults.count == 1 ? "" : "s")."
    }

    func loadMembers(
        for list: BlueskyList,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        isLoadingMembers = true
        errorMessage = nil
        memberCursor = nil
        hasMoreMembers = false

        do {
            let page = try await client.fetchListMembersPage(
                list: list,
                cursor: nil,
                account: account,
                appPassword: appPassword
            )
            members = deduplicatedMembers(page.members)
            memberCursor = page.cursor
            hasMoreMembers = page.cursor != nil
            selectedMemberIDs = selectedMemberIDs.intersection(Set(members.map(\.id)))
            refreshSearchMembershipFilter()
        } catch {
            errorMessage = error.localizedDescription
            members = []
        }

        isLoadingMembers = false
    }

    func loadMoreMembersIfNeeded(
        currentMember: BlueskyListMember?,
        list: BlueskyList,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        guard let currentMember,
              hasMoreMembers,
              !isLoadingMembers,
              !isLoadingMoreMembers,
              currentMember.id == members.suffix(5).first?.id || members.suffix(5).contains(currentMember),
              let cursor = memberCursor else {
            return
        }

        isLoadingMoreMembers = true
        defer { isLoadingMoreMembers = false }

        do {
            let page = try await client.fetchListMembersPage(
                list: list,
                cursor: cursor,
                account: account,
                appPassword: appPassword
            )
            members = deduplicatedMembers(members + page.members)
            memberCursor = page.cursor
            hasMoreMembers = page.cursor != nil
            selectedMemberIDs = selectedMemberIDs.intersection(Set(members.map(\.id)))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadAvailableLists(
        excluding currentList: BlueskyList,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        isLoadingAvailableLists = true

        do {
            let lists = try await client.fetchLists(for: account, appPassword: appPassword)
            availableLists = lists.filter { $0.id != currentList.id }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
            availableLists = []
        }

        isLoadingAvailableLists = false
    }

    func search(
        query: String,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        lastSearchQuery = trimmed

        guard trimmed.count >= 2 else {
            searchResults = []
            searchCursor = nil
            hasMoreSearchResults = false
            isSearching = false
            return
        }

        isSearching = true

        do {
            let page = try await client.searchActorsPage(
                query: trimmed,
                cursor: nil,
                account: account,
                appPassword: appPassword
            )
            guard trimmed == lastSearchQuery else {
                isSearching = false
                return
            }
            searchResults = filteredSearchResults(page.actors)
            searchCursor = page.cursor
            hasMoreSearchResults = page.cursor != nil
            selectedSearchActorIDs = selectedSearchActorIDs.intersection(Set(searchResults.map(\.id)))
        } catch {
            errorMessage = error.localizedDescription
            searchResults = []
            selectedSearchActorIDs = []
            searchCursor = nil
            hasMoreSearchResults = false
        }

        isSearching = false
    }

    func loadMoreSearchResults(
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        guard hasMoreSearchResults,
              !isSearching,
              !isLoadingMoreSearchResults,
              lastSearchQuery.count >= 2,
              let cursor = searchCursor else {
            return
        }
        let requestQuery = lastSearchQuery
        let requestCursor = cursor

        isLoadingMoreSearchResults = true
        defer { isLoadingMoreSearchResults = false }

        do {
            let page = try await client.searchActorsPage(
                query: requestQuery,
                cursor: requestCursor,
                account: account,
                appPassword: appPassword
            )
            guard requestQuery == lastSearchQuery, requestCursor == searchCursor else {
                return
            }
            searchResults = filteredSearchResults(searchResults + page.actors)
            searchCursor = page.cursor
            hasMoreSearchResults = page.cursor != nil
            selectedSearchActorIDs = selectedSearchActorIDs.intersection(Set(searchResults.map(\.id)))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func add(
        actor: BlueskyActor,
        to list: BlueskyList,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        addingActorIDs.insert(actor.did)
        defer { addingActorIDs.remove(actor.did) }

        do {
            try await client.addActor(
                did: actor.did,
                to: list,
                account: account,
                appPassword: appPassword
            )
            searchResults.removeAll { $0.did == actor.did }
            selectedSearchActorIDs.remove(actor.id)
            await loadMembers(for: list, account: account, appPassword: appPassword, using: client)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(
        member: BlueskyListMember,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        removingMemberIDs.insert(member.id)
        defer { removingMemberIDs.remove(member.id) }

        do {
            try await client.removeMember(
                recordURI: member.recordURI,
                account: account,
                appPassword: appPassword
            )
            members.removeAll { $0.id == member.id }
            selectedMemberIDs.remove(member.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateMetadata(
        for list: BlueskyList,
        title: String,
        description: String,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async -> BlueskyList? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            errorMessage = "List title is required."
            return nil
        }

        isUpdatingMetadata = true
        defer { isUpdatingMetadata = false }

        do {
            let updatedList = try await client.updateListMetadata(
                list: list,
                title: trimmedTitle,
                description: trimmedDescription,
                account: account,
                appPassword: appPassword
            )
            errorMessage = nil
            return updatedList
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func isAdding(_ actor: BlueskyActor) -> Bool {
        addingActorIDs.contains(actor.did)
    }

    func isRemoving(_ member: BlueskyListMember) -> Bool {
        removingMemberIDs.contains(member.id)
    }

    func isSelectedForBulkAdd(_ actor: BlueskyActor) -> Bool {
        selectedSearchActorIDs.contains(actor.id)
    }

    func isSelectedForBulkRemoval(_ member: BlueskyListMember) -> Bool {
        selectedMemberIDs.contains(member.id)
    }

    func toggleSearchSelection(for actor: BlueskyActor) {
        if !selectedSearchActorIDs.insert(actor.id).inserted {
            selectedSearchActorIDs.remove(actor.id)
        }
    }

    func toggleMemberSelection(for member: BlueskyListMember) {
        if !selectedMemberIDs.insert(member.id).inserted {
            selectedMemberIDs.remove(member.id)
        }
    }

    func toggleComparisonSelection(for actorDID: String) {
        if !selectedComparisonActorDIDs.insert(actorDID).inserted {
            selectedComparisonActorDIDs.remove(actorDID)
        }
    }

    func selectAllSearchResults() {
        selectedSearchActorIDs = Set(searchResults.map(\.id))
    }

    func clearSearchSelection() {
        selectedSearchActorIDs.removeAll()
    }

    func selectAllFilteredMembers(matching query: String) {
        selectedMemberIDs = Set(filteredMembers(matching: query).map(\.id))
    }

    func clearMemberSelection() {
        selectedMemberIDs.removeAll()
    }

    func selectComparisonBucket(_ bucket: ComparisonBucket) {
        selectedComparisonActorDIDs = Set(comparisonMembers(for: bucket).map { $0.actor.did })
    }

    func clearComparisonSelection() {
        selectedComparisonActorDIDs.removeAll()
    }

    func compare(
        currentList: BlueskyList,
        otherList: BlueskyList,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        isComparingLists = true
        defer { isComparingLists = false }

        do {
            let otherMembers = try await client.fetchListMembers(
                list: otherList,
                account: account,
                appPassword: appPassword
            )
            let currentByDID = Dictionary(uniqueKeysWithValues: members.map { ($0.actor.did, $0) })
            let otherByDID = Dictionary(uniqueKeysWithValues: otherMembers.map { ($0.actor.did, $0) })

            let overlap = currentByDID.keys
                .filter { otherByDID[$0] != nil }
                .compactMap { currentByDID[$0] }
                .sorted { $0.actor.handle.localizedCaseInsensitiveCompare($1.actor.handle) == .orderedAscending }

            let onlyInCurrent = currentByDID.keys
                .filter { otherByDID[$0] == nil }
                .compactMap { currentByDID[$0] }
                .sorted { $0.actor.handle.localizedCaseInsensitiveCompare($1.actor.handle) == .orderedAscending }

            let onlyInOther = otherByDID.keys
                .filter { currentByDID[$0] == nil }
                .compactMap { otherByDID[$0] }
                .sorted { $0.actor.handle.localizedCaseInsensitiveCompare($1.actor.handle) == .orderedAscending }

            comparisonReport = ListComparisonReport(
                otherList: otherList,
                overlap: overlap,
                onlyInCurrent: onlyInCurrent,
                onlyInOther: onlyInOther
            )
            selectedComparisonActorDIDs = []
        } catch {
            errorMessage = error.localizedDescription
            comparisonReport = nil
            selectedComparisonActorDIDs = []
        }
    }

    func clearComparison() {
        comparisonReport = nil
        selectedComparisonActorDIDs = []
    }

    func transferSelectedMembers(
        from sourceList: BlueskyList,
        to targetList: BlueskyList,
        move: Bool,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        let selectedMembers = members.filter { selectedMemberIDs.contains($0.id) }
        guard !selectedMembers.isEmpty else { return }

        let result = await performActorBatch(
            title: move ? "Moving members" : "Copying members",
            actors: selectedMembers.map(\.actor),
            operation: move ? .move : .copy
        ) { actor in
            try await client.addActor(
                did: actor.did,
                to: targetList,
                account: account,
                appPassword: appPassword
            )

            if move, let member = selectedMembers.first(where: { $0.actor.did == actor.did }) {
                try await client.removeMember(
                    recordURI: member.recordURI,
                    account: account,
                    appPassword: appPassword
                )
            }
        }

        if move {
            let removedDIDs = Set(result.succeededActors.map(\.did))
            let removedIDs = Set(selectedMembers.filter { removedDIDs.contains($0.actor.did) }.map(\.id))
            members.removeAll { removedIDs.contains($0.id) }
            selectedMemberIDs.subtract(removedIDs)
        }

        bulkActionResult = result
    }

    func prepareImportPreview(
        from rawInput: String,
        sourceDescription: String,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        let tokens = importedIdentifiers(from: rawInput)
        guard !tokens.isEmpty else {
            errorMessage = "Paste at least one handle, DID, or profile URL."
            return
        }

        isPreparingImportPreview = true
        defer { isPreparingImportPreview = false }

        let existingDIDs = Set(members.map(\.actor.did))
        var seenTokens: Set<String> = []
        var seenResolvedDIDs: Set<String> = []
        var items: [ImportPreviewItem] = []

        for token in tokens {
            let normalizedToken = token.lowercased()
            if !seenTokens.insert(normalizedToken).inserted {
                items.append(
                    ImportPreviewItem(
                        token: token,
                        actor: nil,
                        classification: .duplicate,
                        message: "Duplicate identifier in this import payload."
                    )
                )
                continue
            }

            do {
                let profile = try await client.fetchProfile(
                    did: token,
                    account: account,
                    appPassword: appPassword
                )
                let actor = BlueskyActor(
                    did: profile.did,
                    handle: profile.handle,
                    displayName: profile.displayName,
                    avatarURL: profile.avatarURL
                )

                if existingDIDs.contains(actor.did) {
                    items.append(
                        ImportPreviewItem(
                            token: token,
                            actor: actor,
                            classification: .alreadyPresent,
                            message: "Already a member of this list."
                        )
                    )
                } else if !seenResolvedDIDs.insert(actor.did).inserted {
                    items.append(
                        ImportPreviewItem(
                            token: token,
                            actor: actor,
                            classification: .duplicate,
                            message: "Another entry in this import resolves to the same account."
                        )
                    )
                } else {
                    items.append(
                        ImportPreviewItem(
                            token: token,
                            actor: actor,
                            classification: .ready,
                            message: nil
                        )
                    )
                }
            } catch {
                items.append(
                    ImportPreviewItem(
                        token: token,
                        actor: nil,
                        classification: .unresolved,
                        message: error.localizedDescription
                    )
                )
            }
        }

        importPreview = ImportPreview(
            sourceDescription: sourceDescription,
            items: items
        )
    }

    func commitImportPreview(
        to list: BlueskyList,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        guard let importPreview else { return }

        let actorsToImport = importPreview.items.compactMap { item -> BlueskyActor? in
            switch item.classification {
            case .ready:
                return item.actor
            case .alreadyPresent:
                return nil
            case .duplicate, .unresolved:
                return nil
            }
        }

        guard !actorsToImport.isEmpty else {
            errorMessage = "Nothing is eligible for import."
            return
        }

        isImportingHandles = true
        let result = await performActorBatch(
            title: "Importing handles",
            actors: actorsToImport,
            operation: .import
        ) { actor in
            try await client.addActor(
                did: actor.did,
                to: list,
                account: account,
                appPassword: appPassword
            )
        }
        isImportingHandles = false
        bulkActionResult = result
        self.importPreview = nil
        await loadMembers(for: list, account: account, appPassword: appPassword, using: client)
    }

    func discardImportPreview() {
        importPreview = nil
    }

    func exportRows() -> [String] {
        members.map { member in
            [
                csvField(member.actor.handle),
                csvField(member.actor.did),
                csvField(member.actor.displayName ?? "")
            ].joined(separator: ",")
        }
    }

    func exportDiffRows() -> [String] {
        guard let comparisonReport else { return [] }

        let sections: [(ComparisonBucket, [BlueskyListMember])] = [
            (.overlap, comparisonReport.overlap),
            (.onlyInCurrent, comparisonReport.onlyInCurrent),
            (.onlyInOther, comparisonReport.onlyInOther)
        ]

        return sections.flatMap { bucket, members in
            members.map { member in
                [
                    csvField(bucket.title),
                    csvField(member.actor.handle),
                    csvField(member.actor.did),
                    csvField(member.actor.displayName ?? "")
                ].joined(separator: ",")
            }
        }
    }

    func bulkAddSelectedActors(
        to list: BlueskyList,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        let selectedActors = searchResults.filter { selectedSearchActorIDs.contains($0.id) }
        guard !selectedActors.isEmpty else { return }

        let result = await performActorBatch(
            title: "Adding selected results",
            actors: selectedActors,
            operation: .add
        ) { actor in
            try await client.addActor(
                did: actor.did,
                to: list,
                account: account,
                appPassword: appPassword
            )
        }

        bulkActionResult = result
        searchResults.removeAll { actor in
            result.succeededActors.contains(where: { $0.id == actor.id })
        }
        clearSearchSelection()
        await loadMembers(for: list, account: account, appPassword: appPassword, using: client)
    }

    func bulkRemoveSelectedMembers(
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        let selectedMembers = members.filter { selectedMemberIDs.contains($0.id) }
        guard !selectedMembers.isEmpty else { return }

        let result = await performActorBatch(
            title: "Removing members",
            actors: selectedMembers.map(\.actor),
            operation: .remove,
            addingActorState: false,
            removingMemberIDsByActorDID: Dictionary(
                uniqueKeysWithValues: selectedMembers.map { ($0.actor.did, $0.id) }
            )
        ) { actor in
            guard let member = selectedMembers.first(where: { $0.actor.did == actor.did }) else {
                throw BlueskyAPIError.invalidResponse
            }

            try await client.removeMember(
                recordURI: member.recordURI,
                account: account,
                appPassword: appPassword
            )
        }

        let removedDIDs = Set(result.succeededActors.map(\.did))
        let removedIDs = Set(selectedMembers.filter { removedDIDs.contains($0.actor.did) }.map(\.id))
        members.removeAll { removedIDs.contains($0.id) }
        selectedMemberIDs.subtract(removedIDs)
        bulkActionResult = result
    }

    func bulkAddComparisonSelection(
        to list: BlueskyList,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        let actors = selectedComparisonMembers().map(\.actor)
        guard !actors.isEmpty else { return }

        let result = await performActorBatch(
            title: "Adding comparison results",
            actors: actors,
            operation: .copy
        ) { actor in
            try await client.addActor(
                did: actor.did,
                to: list,
                account: account,
                appPassword: appPassword
            )
        }

        bulkActionResult = result
        selectedComparisonActorDIDs.subtract(result.succeededActors.map(\.did))
        await loadMembers(for: list, account: account, appPassword: appPassword, using: client)
    }

    func retryFailures(
        from result: ListBulkActionResult,
        currentList: BlueskyList,
        comparisonList: BlueskyList?,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async {
        let failedActors = result.failures.map(\.actor)
        guard !failedActors.isEmpty else { return }

        switch result.operation {
        case .add, .import:
            let retryResult = await performActorBatch(
                title: "Retrying \(result.operation.title.lowercased())",
                actors: failedActors,
                operation: result.operation
            ) { actor in
                try await client.addActor(
                    did: actor.did,
                    to: currentList,
                    account: account,
                    appPassword: appPassword
                )
            }
            bulkActionResult = retryResult
            await loadMembers(for: currentList, account: account, appPassword: appPassword, using: client)

        case .remove:
            let failedMembers = members.filter { member in
                failedActors.contains(where: { $0.did == member.actor.did })
            }
            let retryResult = await performActorBatch(
                title: "Retrying removals",
                actors: failedMembers.map(\.actor),
                operation: .remove,
                addingActorState: false,
                removingMemberIDsByActorDID: Dictionary(
                    uniqueKeysWithValues: failedMembers.map { ($0.actor.did, $0.id) }
                )
            ) { actor in
                guard let member = failedMembers.first(where: { $0.actor.did == actor.did }) else {
                    throw BlueskyAPIError.invalidResponse
                }
                try await client.removeMember(
                    recordURI: member.recordURI,
                    account: account,
                    appPassword: appPassword
                )
            }
            let removedDIDs = Set(retryResult.succeededActors.map(\.did))
            let removedIDs = Set(failedMembers.filter { removedDIDs.contains($0.actor.did) }.map(\.id))
            members.removeAll { removedDIDs.contains($0.actor.did) }
            selectedMemberIDs.subtract(removedIDs)
            bulkActionResult = retryResult

        case .copy, .move:
            guard let comparisonList else {
                errorMessage = "Select a comparison list before retrying this action."
                return
            }
            let failedMembers = members.filter { member in
                failedActors.contains(where: { $0.did == member.actor.did })
            }
            let retryResult = await performActorBatch(
                title: "Retrying \(result.operation.title.lowercased())",
                actors: failedActors,
                operation: result.operation,
                removingMemberIDsByActorDID: result.operation == .move
                    ? Dictionary(
                        uniqueKeysWithValues: failedMembers
                            .map { ($0.actor.did, $0.id) }
                      )
                    : [:]
            ) { [self] actor in
                try await client.addActor(
                    did: actor.did,
                    to: comparisonList,
                    account: account,
                    appPassword: appPassword
                )

                if result.operation == .move,
                   let member = members.first(where: { $0.actor.did == actor.did }) {
                    try await client.removeMember(
                        recordURI: member.recordURI,
                        account: account,
                        appPassword: appPassword
                    )
                }
            }
            if result.operation == .move {
                let movedDIDs = Set(retryResult.succeededActors.map(\.did))
                let movedIDs = Set(members.filter { movedDIDs.contains($0.actor.did) }.map(\.id))
                members.removeAll { movedDIDs.contains($0.actor.did) }
                selectedMemberIDs.subtract(movedIDs)
            }
            bulkActionResult = retryResult
        }
    }

    func filteredMembers(matching query: String) -> [BlueskyListMember] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            return members
        }

        return members.filter {
            $0.actor.handle.lowercased().contains(trimmed) ||
            ($0.actor.displayName?.lowercased().contains(trimmed) ?? false)
        }
    }

    func comparisonMembers(for bucket: ComparisonBucket) -> [BlueskyListMember] {
        guard let comparisonReport else { return [] }

        switch bucket {
        case .overlap:
            return comparisonReport.overlap
        case .onlyInCurrent:
            return comparisonReport.onlyInCurrent
        case .onlyInOther:
            return comparisonReport.onlyInOther
        }
    }

    func selectedComparisonMembers() -> [BlueskyListMember] {
        guard let comparisonReport else { return [] }

        let all = comparisonReport.overlap + comparisonReport.onlyInCurrent + comparisonReport.onlyInOther
        let filtered = all.filter { selectedComparisonActorDIDs.contains($0.actor.did) }

        return filtered.sorted {
            $0.actor.handle.localizedCaseInsensitiveCompare($1.actor.handle) == .orderedAscending
        }
    }

    private func performActorBatch(
        title: String,
        actors: [BlueskyActor],
        operation: ListBulkActionResult.Operation,
        addingActorState: Bool = true,
        removingMemberIDsByActorDID: [String: String] = [:],
        action: @escaping (BlueskyActor) async throws -> Void
    ) async -> ListBulkActionResult {
        isPerformingBulkAction = true
        defer {
            isPerformingBulkAction = false
            batchProgress = nil
        }

        var succeededActors: [BlueskyActor] = []
        var failures: [ListBulkActionResult.Failure] = []

        for (index, actor) in actors.enumerated() {
            batchProgress = BatchProgress(
                title: title,
                completedCount: index,
                totalCount: actors.count,
                currentHandle: actor.handle
            )
            if addingActorState {
                addingActorIDs.insert(actor.did)
            }
            if let memberID = removingMemberIDsByActorDID[actor.did] {
                removingMemberIDs.insert(memberID)
            }

            do {
                try await action(actor)
                succeededActors.append(actor)
            } catch {
                failures.append(.init(actor: actor, message: error.localizedDescription))
            }

            addingActorIDs.remove(actor.did)
            if let memberID = removingMemberIDsByActorDID[actor.did] {
                removingMemberIDs.remove(memberID)
            }
            batchProgress = BatchProgress(
                title: title,
                completedCount: index + 1,
                totalCount: actors.count,
                currentHandle: actor.handle
            )
        }

        return ListBulkActionResult(
            operation: operation,
            succeededActors: succeededActors,
            failures: failures
        )
    }

    private func refreshSearchMembershipFilter() {
        searchResults = filteredSearchResults(searchResults)
        selectedSearchActorIDs = selectedSearchActorIDs.intersection(Set(searchResults.map(\.id)))
    }

    private func filteredSearchResults(_ actors: [BlueskyActor]) -> [BlueskyActor] {
        let existing = Set(members.map(\.actor.did))
        var deduplicated: [BlueskyActor] = []
        var seen: Set<String> = []

        for actor in actors where !existing.contains(actor.did) {
            if seen.insert(actor.did).inserted {
                deduplicated.append(actor)
            }
        }

        return deduplicated
    }

    private func deduplicatedMembers(_ members: [BlueskyListMember]) -> [BlueskyListMember] {
        var deduplicated: [BlueskyListMember] = []
        var seen: Set<String> = []

        for member in members where seen.insert(member.id).inserted {
            deduplicated.append(member)
        }

        return deduplicated
    }

    private func importedIdentifiers(from rawInput: String) -> [String] {
        let separators = CharacterSet.newlines
        let rows = rawInput
            .components(separatedBy: separators)
            .flatMap { line -> [String] in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return [] }

                if trimmed.contains(",") {
                    return trimmed.split(separator: ",").map(String.init)
                }

                if trimmed.contains(";") {
                    return trimmed.split(separator: ";").map(String.init)
                }

                return trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
            }
            .map { normalizedImportedIdentifier($0) }
            .filter { !$0.isEmpty }

        return rows
    }

    private func normalizedImportedIdentifier(_ value: String) -> String {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard !trimmed.isEmpty else { return "" }

        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("https://bsky.app/profile/") {
            return extractProfileIdentifier(from: trimmed)
        }

        if lowercased.hasPrefix("http://bsky.app/profile/") {
            return extractProfileIdentifier(from: trimmed)
        }

        if lowercased.hasPrefix("bsky.app/profile/") {
            return extractProfileIdentifier(from: "https://\(trimmed)")
        }

        if trimmed.hasPrefix("@") {
            return String(trimmed.dropFirst())
        }

        return trimmed
    }

    private func extractProfileIdentifier(from value: String) -> String {
        guard let url = URL(string: value),
              let profileIndex = url.pathComponents.firstIndex(of: "profile"),
              url.pathComponents.indices.contains(profileIndex + 1) else {
            return value
        }

        return url.pathComponents[profileIndex + 1]
    }

    private func csvField(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
