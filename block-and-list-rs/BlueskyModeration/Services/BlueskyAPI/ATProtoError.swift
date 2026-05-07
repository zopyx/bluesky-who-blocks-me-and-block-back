import Foundation

enum ATProtoError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case authenticationFailed
    case networkError(Error)
    case invalidHandle
    case pdsNotFound
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let message):
            if let message = message {
                return "Server error (\(statusCode)): \(message)"
            }
            return "Server error (\(statusCode))"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .authenticationFailed:
            return "Authentication failed. Please check your handle and app password."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidHandle:
            return "Invalid Bluesky handle"
        case .pdsNotFound:
            return "Could not find your personal data server"
        case .sessionExpired:
            return "Session expired. Please sign in again."
        }
    }
}

struct ATProtoErrorResponse: Decodable {
    let error: String?
    let message: String?
}
