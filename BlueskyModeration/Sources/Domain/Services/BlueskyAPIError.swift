import Foundation

enum BlueskyAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case missingCredentials
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The Bluesky endpoint URL is invalid."
        case .invalidResponse:
            return "Bluesky returned an unexpected response."
        case .unauthorized:
            return "Bluesky rejected the credentials. Check the handle and app password."
        case .missingCredentials:
            return "No saved app password was found for this account."
        case let .server(message):
            return "Bluesky returned an error: \(message)"
        }
    }
}

struct APIErrorPayload: Decodable {
    let error: String?
    let message: String?
}
