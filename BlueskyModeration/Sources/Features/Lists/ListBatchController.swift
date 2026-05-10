import Foundation

@MainActor
final class ListBatchController {
    private let baseDelay: UInt64

    init(baseDelay: UInt64 = 300_000_000) {
        self.baseDelay = baseDelay
    }

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
            guard !Task.isCancelled else { break }

            onProgress?(
                BatchProgress(
                    title: title,
                    completedCount: index,
                    totalCount: actors.count,
                    currentHandle: actor.handle
                )
            )
            onActorStart?(actor)

            // Attempt with retry
            var lastError: Error?
            for _ in 0..<3 {
                guard !Task.isCancelled else { break }
                do {
                    try await action(actor)
                    succeededActors.append(actor)
                    lastError = nil
                    break
                } catch {
                    lastError = error
                    try? await Task.sleep(for: .nanoseconds(baseDelay))
                }
            }

            if let lastError {
                failures.append(.init(actor: actor, message: lastError.localizedDescription))
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
                try? await Task.sleep(for: .nanoseconds(baseDelay))
            }
        }

        return ListBulkActionResult(
            operation: operation,
            succeededActors: succeededActors,
            failures: failures
        )
    }
}
