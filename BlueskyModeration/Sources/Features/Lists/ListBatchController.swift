import Foundation

@MainActor
final class ListBatchController {
    func performBatch(
        title: String,
        actors: [BlueskyActor],
        operation: ListBulkActionResult.Operation,
        onProgress: ((BatchProgress) -> Void)? = nil,
        onActorStart: ((BlueskyActor) -> Void)? = nil,
        onActorComplete: ((BlueskyActor) -> Void)? = nil,
        action: @escaping (BlueskyActor) async throws -> Void
    ) async -> ListBulkActionResult {
        var succeededActors: [BlueskyActor] = []
        var failures: [ListBulkActionResult.Failure] = []

        for (index, actor) in actors.enumerated() {
            onProgress?(
                BatchProgress(
                    title: title,
                    completedCount: index,
                    totalCount: actors.count,
                    currentHandle: actor.handle
                )
            )
            onActorStart?(actor)

            do {
                try await action(actor)
                succeededActors.append(actor)
            } catch {
                failures.append(.init(actor: actor, message: error.localizedDescription))
            }

            onActorComplete?(actor)
            onProgress?(
                BatchProgress(
                    title: title,
                    completedCount: index + 1,
                    totalCount: actors.count,
                    currentHandle: actor.handle
                )
            )

            if index < actors.count - 1 {
                try? await Task.sleep(for: .milliseconds(300))
            }
        }

        return ListBulkActionResult(
            operation: operation,
            succeededActors: succeededActors,
            failures: failures
        )
    }
}
