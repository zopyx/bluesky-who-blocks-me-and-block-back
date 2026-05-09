import Foundation

protocol BlueskyRequestExecuting: Sendable {
    func send<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        body: Body?,
        accessToken: String?,
        hostURL: URL?
    ) async throws -> Response

    func send<Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        accessToken: String?,
        hostURL: URL?
    ) async throws -> Response
}

struct BlueskyRequestExecutor: BlueskyRequestExecuting {
    static func makePinnedSession() -> URLSession {
        let delegate = PinningDelegate()
        return URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    }
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = .bskySocial, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func send<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Body?,
        accessToken: String?,
        hostURL: URL?
    ) async throws -> Response {
        let start = CFAbsoluteTimeGetCurrent()
        let targetURL = hostURL ?? baseURL
        guard var components = URLComponents(url: targetURL.appendingPathComponent("xrpc/\(path)"), resolvingAgainstBaseURL: false) else {
            throw BlueskyAPIError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw BlueskyAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Rulyx Moderation App", forHTTPHeaderField: "User-Agent")

        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BlueskyAPIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw BlueskyAPIError.unauthorized
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            if let errorPayload = try? JSONDecoder().decode(APIErrorPayload.self, from: data) {
                throw BlueskyAPIError.server(errorPayload.message ?? errorPayload.error ?? "Bluesky request failed.")
            }
            throw BlueskyAPIError.invalidResponse
        }

        AppLogger.performance.debug("\(method, privacy: .public) \(path, privacy: .public) took \(CFAbsoluteTimeGetCurrent() - start, format: .fixed(precision: 2))s (\(httpResponse.statusCode))")

        do {
            let decodedData = data.isEmpty ? Data("{}".utf8) : data
            return try JSONDecoder().decode(Response.self, from: decodedData)
        } catch {
            AppLogger.performance.debug("Decoding failure for \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw BlueskyAPIError.invalidResponse
        }
    }

    func send<Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        accessToken: String?,
        hostURL: URL?
    ) async throws -> Response {
        try await send(
            path: path,
            method: method,
            queryItems: queryItems,
            body: Optional<String>.none,
            accessToken: accessToken,
            hostURL: hostURL
        )
    }
}

private final class PinningDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.host == "bsky.social" else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
