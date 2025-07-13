import Foundation

@available(iOS 18.0, *)
public final class HTTPClient: ConclaveAPIClient, Sendable {

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime, .withFractionalSeconds,
        ]
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            guard let date = formatter.date(from: dateStr) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date format: \(dateStr)"
                )
            }
            return date
        }

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
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

    // MARK: - Health & Stats

    public func health() async throws -> HealthResponse {
        try await performRequest(path: "/health", method: .GET)
    }

    public func stats() async throws -> StatsResponse {
        try await performRequest(path: "/stats", method: .GET)
    }

    // MARK: - User Endpoints

    public func getUserHistory(clerkUserId: String) async throws -> GameHistory
    {
        try await performRequest(
            path: "/users/\(clerkUserId)/history",
            method: .GET
        )
    }

    public func getUserGames(clerkUserId: String) async throws
        -> [GameWithUsers]
    {
        try await performRequest(
            path: "/users/\(clerkUserId)/games",
            method: .GET
        )
    }

    public func getAvailableGames(clerkUserId: String) async throws
        -> [GameWithUsers]
    {
        try await performRequest(
            path: "/users/\(clerkUserId)/available-games",
            method: .GET
        )
    }

    // MARK: - Game Endpoints

    public func createGame(request: CreateGameRequest) async throws -> Game {
        try await performRequest(path: "/games", method: .POST, body: request)
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

    public func joinGame(gameId: UUID, request: JoinGameRequest) async throws
        -> Player
    {
        try await performRequest(
            path: "/games/\(gameId.uuidString)/join",
            method: .POST,
            body: request
        )
    }

    public func leaveGame(gameId: UUID, request: JoinGameRequest) async throws {
        let _: EmptyResponse = try await performRequest(
            path: "/games/\(gameId.uuidString)/leave",
            method: .POST,
            body: request
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
            method: .PUT
        )
    }

    public func getRecentLifeChanges(gameId: UUID) async throws -> [LifeChange]
    {
        try await performRequest(
            path: "/games/\(gameId.uuidString)/life-changes",
            method: .GET
        )
    }

    // MARK: - Private Methods

    private func performRequest<T: Codable>(
        path: String,
        method: HTTPMethod,
        body: (any Encodable)? = nil
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw ConclaveError.encodingError(error.localizedDescription)
            }
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ConclaveError.unknown("Invalid response type")
            }

            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = try? decoder.decode(
                    APIErrorResponse.self,
                    from: data
                )
                throw ConclaveError.httpError(
                    statusCode: httpResponse.statusCode,
                    message: errorMessage?.message ?? errorMessage?.error
                )
            }

            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }

            do {
                print(
                    "[HTTPClient] Raw response: \(String(data: data, encoding: .utf8) ?? "No data returned")"
                )
                return try decoder.decode(T.self, from: data)
            } catch {
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
