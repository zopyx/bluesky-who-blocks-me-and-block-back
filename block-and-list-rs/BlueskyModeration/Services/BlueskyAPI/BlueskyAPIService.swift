import Foundation

protocol BlueskyAPIProtocol: Sendable {
    func resolveHandle(_ handle: String) async throws -> String
    func getPDS(did: String) async throws -> String
    func createSession(identifier: String, password: String, pds: String?) async throws -> CreateSessionResponse
    func getLists(actor: String, accessJwt: String, pds: String?) async throws -> [ATProtoList]
    func getList(listUri: String, accessJwt: String, pds: String?) async throws -> GetListResponse
}

actor BlueskyAPIService: BlueskyAPIProtocol {
    static let shared = BlueskyAPIService()

    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    private let bskySocial = "https://bsky.social"
    private let bskyPublic = "https://public.api.bsky.app"

    init(session: URLSession = .shared) {
        self.session = session
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601

        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Authentication

    func createSession(identifier: String, password: String, pds: String? = nil) async throws -> CreateSessionResponse {
        let body = CreateSessionRequest(identifier: identifier, password: password)
        let data = try jsonEncoder.encode(body)

        let hosts = [pds, bskySocial].compactMap { $0 }
        var lastError: Error?

        for host in hosts {
            do {
                let request = try makeRequest(
                    baseURL: host,
                    nsid: "com.atproto.server.createSession",
                    method: "POST",
                    body: data
                )
                let (responseData, response) = try await session.data(for: request)
                try validateResponse(response, data: responseData)
                return try jsonDecoder.decode(CreateSessionResponse.self, from: responseData)
            } catch let error as ATProtoError {
                lastError = error
                continue
            } catch {
                lastError = error
                continue
            }
        }

        throw lastError ?? ATProtoError.authenticationFailed
    }

    // MARK: - Lists

    func getLists(actor: String, accessJwt: String, pds: String? = nil) async throws -> [ATProtoList] {
        let host = pds ?? bskyPublic
        var allLists: [ATProtoList] = []
        var cursor: String?

        repeat {
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "actor", value: actor),
                URLQueryItem(name: "limit", value: "100")
            ]
            if let cursor = cursor {
                queryItems.append(URLQueryItem(name: "cursor", value: cursor))
            }

            let request = try makeRequest(
                baseURL: host,
                nsid: "app.bsky.graph.getLists",
                method: "GET",
                queryItems: queryItems,
                accessJwt: accessJwt
            )

            let (data, response) = try await session.data(for: request)
            try validateResponse(response, data: data)
            let result = try jsonDecoder.decode(GetListsResponse.self, from: data)
            allLists.append(contentsOf: result.lists)
            cursor = result.cursor
        } while cursor != nil

        return allLists
    }

    func getList(listUri: String, accessJwt: String, pds: String? = nil) async throws -> GetListResponse {
        let host = pds ?? bskyPublic
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "list", value: listUri),
            URLQueryItem(name: "limit", value: "100")
        ]

        let request = try makeRequest(
            baseURL: host,
            nsid: "app.bsky.graph.getList",
            method: "GET",
            queryItems: queryItems,
            accessJwt: accessJwt
        )

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try jsonDecoder.decode(GetListResponse.self, from: data)
    }

    // MARK: - Identity Resolution

    func resolveHandle(_ handle: String) async throws -> String {
        let url = URL(string: "\(bskySocial)/xrpc/com.atproto.identity.resolveHandle?handle=\(handle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? handle)")!
        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        let result = try jsonDecoder.decode(ResolveHandleResponse.self, from: data)
        return result.did
    }

    func getPDS(did: String) async throws -> String {
        if did.hasPrefix("did:plc:") {
            let url = URL(string: "https://plc.directory/\(did)")!
            let request = URLRequest(url: url)
            let (data, response) = try await session.data(for: request)
            try validateResponse(response, data: data)
            let doc = try jsonDecoder.decode(DIDDocument.self, from: data)

            if let service = doc.service?.first(where: { $0.type == "AtprotoPersonalDataServer" || $0.id.hasSuffix("#atproto_pds") }) {
                return service.serviceEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }
        } else if did.hasPrefix("did:web:") {
            let domain = did.dropFirst("did:web:".count)
            let url = URL(string: "https://\(domain)/.well-known/did.json")!
            let request = URLRequest(url: url)
            let (data, response) = try await session.data(for: request)
            try validateResponse(response, data: data)
            let doc = try jsonDecoder.decode(DIDDocument.self, from: data)

            if let service = doc.service?.first(where: { $0.type == "AtprotoPersonalDataServer" || $0.id.hasSuffix("#atproto_pds") }) {
                return service.serviceEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }
        }

        throw ATProtoError.pdsNotFound
    }

    // MARK: - Private Helpers

    private func makeRequest(
        baseURL: String,
        nsid: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil,
        accessJwt: String? = nil
    ) throws -> URLRequest {
        var components = URLComponents(string: "\(baseURL)/xrpc/\(nsid)")!
        if let queryItems = queryItems {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("BlueskyModeration/1.0", forHTTPHeaderField: "User-Agent")

        if let accessJwt = accessJwt {
            request.setValue("Bearer \(accessJwt)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        return request
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ATProtoError.invalidResponse
        }

        let statusCode = httpResponse.statusCode

        guard (200...299).contains(statusCode) else {
            var message: String?
            if let errorResponse = try? jsonDecoder.decode(ATProtoErrorResponse.self, from: data) {
                message = errorResponse.message ?? errorResponse.error
            } else if let text = String(data: data, encoding: .utf8) {
                message = String(text.prefix(200))
            }

            if statusCode == 401 || statusCode == 403 {
                throw ATProtoError.authenticationFailed
            }

            throw ATProtoError.httpError(statusCode: statusCode, message: message)
        }
    }
}
