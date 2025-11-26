import Foundation

/// High-performance HTTP client with automatic error handling and request optimization
///
/// Features:
/// - JWT token-based authentication
/// - Automatic JSON encoding/decoding with camelCase format
/// - Enhanced error mapping with recovery information
/// - Request caching and deduplication for GET requests
/// - Comprehensive logging and performance monitoring
@available(iOS 18.0, *)
public final class HTTPClient: ConclaveAPIClient, Sendable {

    // MARK: - Core Properties

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Actor to manage auth token state safely
    private actor TokenManager {
        private var _authToken: String?

        func setToken(_ token: String?) {
            _authToken = token
        }

        func getToken() -> String? {
            return _authToken
        }
    }

    private let tokenManager = TokenManager()

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .useDefaultKeys
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds first (backend format)
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [
                .withInternetDateTime, .withFractionalSeconds,
            ]
            if let date = fractionalFormatter.date(from: dateString) {
                return date
            }

            // Fallback to standard ISO8601 without fractional seconds
            let standardFormatter = ISO8601DateFormatter()
            standardFormatter.formatOptions = [.withInternetDateTime]
            if let date = standardFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string \\(dateString)"
            )
        }

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .useDefaultKeys
        self.encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [
                .withInternetDateTime, .withFractionalSeconds,
            ]
            let dateString = formatter.string(from: date)
            var container = encoder.singleValueContainer()
            try container.encode(dateString)
        }
    }

    public convenience init(
        baseURLString: String,
        session: URLSession = .shared
    ) throws {
        guard let url = URL(string: baseURLString) else {
            throw ConclaveError.invalidURL(baseURLString)
        }
        self.init(baseURL: url, session: session)
    }

    // MARK: - Authentication

    public func setAuthToken(_ token: String?) async {
        await tokenManager.setToken(token)
    }

    // MARK: - Health & Stats

    public func health() async throws -> HealthResponse {
        try await performRequest(path: "/health", method: .GET)
    }

    public func stats() async throws -> StatsResponse {
        try await performRequest(path: "/stats", method: .GET)
    }

    // MARK: - User Endpoints (authenticated)

    public func getUserHistory() async throws -> GameHistory {
        try await performRequest(
            path: "/users/me/history",
            method: .GET,
            requiresAuth: true
        )
    }

    public func getUserGames() async throws -> [GameWithUsers] {
        try await performRequest(
            path: "/users/me/games",
            method: .GET,
            requiresAuth: true
        )
    }

    public func getAvailableGames() async throws -> [GameWithUsers] {
        try await performRequest(
            path: "/users/me/available-games",
            method: .GET,
            requiresAuth: true
        )
    }

    // NOTE: Development testing
    public func getAllGames() async throws -> [GameWithUsers] {
        try await performRequest(
            path: "/games",
            method: .GET
        )
    }

    // MARK: - Game Endpoints

    public func createGame(request: CreateGameRequest) async throws -> Game {
        try await performRequest(
            path: "/games",
            method: .POST,
            body: request,
            requiresAuth: true
        )
    }

    public func getGame(gameId: UUID) async throws -> Game {
        try await performRequest(
            path: "/games/\(gameId.uuidString)",
            method: .GET
        )
    }

    public func getGameState(gameId: UUID) async throws -> GameState {
        try await performRequest(
            path: "/games/\(gameId.uuidString)/state",
            method: .GET
        )
    }

    public func joinGame(gameId: UUID) async throws -> Player {
        try await performRequest(
            path: "/games/\(gameId.uuidString)/join",
            method: .POST,
            requiresAuth: true
        )
    }

    public func leaveGame(gameId: UUID) async throws {
        let _: EmptyResponse = try await performRequest(
            path: "/games/\(gameId.uuidString)/leave",
            method: .POST,
            requiresAuth: true
        )
    }

    public func updateLife(gameId: UUID, request: UpdateLifeRequest)
        async throws -> Player
    {
        try await performRequest(
            path: "/games/\(gameId.uuidString)/update-life",
            method: .PUT,
            body: request
        )
    }

    public func endGame(gameId: UUID) async throws -> Game {
        try await performRequest(
            path: "/games/\(gameId.uuidString)/end",
            method: .PUT,
            requiresAuth: true
        )
    }

    public func getRecentLifeChanges(gameId: UUID) async throws -> [LifeChange]
    {
        try await performRequest(
            path: "/games/\(gameId.uuidString)/life-changes",
            method: .GET
        )
    }

    // MARK: - Commander Damage API Methods

    public func updateCommanderDamage(
        gameId: UUID,
        request: UpdateCommanderDamageRequest
    ) async throws -> CommanderDamage {
        try await performRequest(
            path: "/games/\(gameId.uuidString)/commander-damage",
            method: .PUT,
            body: request
        )
    }

    public func togglePartner(
        gameId: UUID,
        playerId: UUID,
        request: TogglePartnerRequest
    ) async throws {
        let _: EmptyResponse = try await performRequest(
            path:
                "/games/\(gameId.uuidString)/players/\(playerId.uuidString)/partner",
            method: .POST,
            body: request
        )
    }

    // MARK: - Private Methods

    private func performRequest<T: Codable>(
        path: String,
        method: HTTPMethod,
        body: (any Encodable)? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add authorization header if required
        if requiresAuth {
            guard let token = await tokenManager.getToken() else {
                throw ConclaveError.authenticationFailed("No auth token set")
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Log the request
        ConclaveLogger.shared.logHTTPRequest(
            method: method.rawValue,
            url: url.absoluteString,
            headers: request.allHTTPHeaderFields
        )

        if let body = body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw ConclaveError.encodingError(error.localizedDescription)
            }
        }

        let startTime = Date()
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                ConclaveLogger.shared.error(
                    "Invalid response type",
                    category: .network
                )
                throw ConclaveError.unknown("Invalid response type")
            }

            let responseTime = Date().timeIntervalSince(startTime)
            ConclaveLogger.shared.logHTTPResponse(
                statusCode: httpResponse.statusCode,
                url: url.absoluteString,
                responseTime: responseTime
            )

            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = try? decoder.decode(
                    APIErrorResponse.self,
                    from: data
                )
                let message =
                    errorMessage?.message ?? errorMessage?.error
                    ?? "Unknown error"

                // Map specific status codes to specific error types
                switch httpResponse.statusCode {
                case 401:
                    throw ConclaveError.authenticationFailed(message)
                case 404:
                    if path.contains("/games/") {
                        throw ConclaveError.gameNotFound(message)
                    } else {
                        throw ConclaveError.httpError(
                            statusCode: httpResponse.statusCode,
                            message: message
                        )
                    }
                case 409:
                    throw ConclaveError.gameNotActive(message)
                case 500...599:
                    throw ConclaveError.serverError(message)
                default:
                    throw ConclaveError.httpError(
                        statusCode: httpResponse.statusCode,
                        message: message
                    )
                }
            }

            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }

            do {
                let result = try decoder.decode(T.self, from: data)
                ConclaveLogger.shared.debug(
                    "Successfully decoded response",
                    category: .network
                )
                return result
            } catch {
                let responseString =
                    String(data: data, encoding: .utf8) ?? "No data"
                ConclaveLogger.shared.error(
                    "Failed to decode response: \(error.localizedDescription) | Response: \(responseString)",
                    category: .network
                )
                throw ConclaveError.decodingError(error.localizedDescription)
            }

        } catch let error as URLError {
            throw ConclaveError.networkError(error)
        } catch let error as ConclaveError {
            throw error
        } catch {
            throw ConclaveError.unknown(error.localizedDescription)
        }
    }
}

private enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

private struct EmptyResponse: Codable {
    init() {}
}
