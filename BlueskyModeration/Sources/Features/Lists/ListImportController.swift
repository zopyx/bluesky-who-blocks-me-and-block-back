import Foundation

@MainActor
final class ListImportController {
    func preparePreview(
        from rawInput: String,
        sourceDescription: String,
        existingMemberDIDs: Set<String>,
        account: AppAccount,
        appPassword: String,
        using client: LiveBlueskyClient
    ) async throws -> ImportPreview {
        let start = CFAbsoluteTimeGetCurrent()
        let tokens = importedIdentifiers(from: rawInput)
        guard !tokens.isEmpty else {
            throw AppError(category: .validation, message: "Paste at least one handle, DID, or profile URL.")
        }

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

                if existingMemberDIDs.contains(actor.did) {
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

        AppLogger.performance.debug("Import preview for '\(sourceDescription, privacy: .public)' with \(tokens.count) tokens took \(CFAbsoluteTimeGetCurrent() - start, format: .fixed(precision: 2))s")

        return ImportPreview(
            sourceDescription: sourceDescription,
            items: items
        )
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
}
