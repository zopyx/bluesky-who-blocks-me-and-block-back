import Foundation

@MainActor
final class ListDetailViewModel: ObservableObject {
    @Published var members: [BlueskyListMember] = []
    @Published var filteredMembers: [BlueskyListMember] = []
    @Published var searchResults: [BlueskyActor] = []
    @Published var availableLists: [BlueskyList] = []
    @Published var comparisonReport: ListComparisonReport?
    @Published var importPreview: ImportPreview?
    @Published var isLoadingMembers = false
    @Published var isLoadingMoreMembers = false
    @Published var hasMoreMembers = false
    @Published var isLoadingAvailableLists = false
    @Published var isSearching = false
    @Published var isLoadingMoreSearchResults = false
    @Published var hasMoreSearchResults = false
    @Published var isComparingLists = false
    @Published var isPreparingImportPreview = false
    @Published var isImportingHandles = false
    @Published var isUpdatingMetadata = false
    @Published var isPerformingBulkAction = false
    @Published var batchProgress: BatchProgress?
    @Published var addingActorIDs: Set<String> = []
    @Published var removingMemberIDs: Set<String> = []
    @Published var selectedSearchActorIDs: Set<String> = []
    @Published var selectedMemberIDs: Set<String> = []
    @Published var selectedComparisonActorDIDs: Set<String> = []
    @Published var bulkActionResult: ListBulkActionResult?
    @Published var errorMessage: String?
    @Published var membersErrorMessage: String?
    @Published var searchErrorMessage: String?

    let membersController = ListMembersController()
    var searchCursor: String?
    var lastSearchQuery = ""
    var currentMemberFilterQuery = ""
    let importController = ListImportController()
    let diffController = ListDiffController()
    let batchController = ListBatchController()

    /// Flag set to true when the user requests batch cancellation.
    /// Checked by the batch controller via the isCancelled closure.
    private(set) var isBatchCancelled = false

    /// Cancels the currently running batch operation, if any.
    func cancelBatch() {
        isBatchCancelled = true
        isPerformingBulkAction = false
    }

    /// Resets the cancellation flag before starting a new batch.
    private func resetBatchCancellation() {
        isBatchCancelled = false
    }
}
