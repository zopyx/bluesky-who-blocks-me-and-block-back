import Foundation
import Observation

@Observable
final class ListViewModel {
    var lists: [BlueskyList] = []
    var curationLists: [BlueskyList] { lists.filter { $0.purpose == .curation } }
    var moderationLists: [BlueskyList] { lists.filter { $0.purpose == .moderation } }
    var isLoading = false
    var errorMessage: String?
    var searchText = ""

    var filteredLists: [BlueskyList] {
        if searchText.isEmpty { return lists }
        return lists.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.description ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    private let apiService = BlueskyAPIService.shared

    func fetchLists(for session: AccountSession) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let protoLists = try await apiService.getLists(
                actor: session.did,
                accessJwt: session.accessJwt,
                pds: session.pdsEndpoint
            )

            let blueskyLists = protoLists.map { BlueskyList(from: $0) }

            await MainActor.run {
                self.lists = blueskyLists
            }
        } catch let error as ATProtoError {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch lists"
            }
        }
    }

    func clear() {
        lists = []
        errorMessage = nil
    }
}
