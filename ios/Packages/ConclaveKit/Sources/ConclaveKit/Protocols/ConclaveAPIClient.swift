import Foundation

public protocol ConclaveAPIClient: Sendable {

    // MARK: - Health & Stats
    func health() async throws -> HealthResponse
    func stats() async throws -> StatsResponse

    // MARK: - User Endpoints
    func getUserHistory(clerkUserId: String) async throws -> GameHistory
    func getUserGames(clerkUserId: String) async throws -> [GameWithUsers]
    func getAvailableGames(clerkUserId: String) async throws -> [GameWithUsers]

    // MARK: - Game Endpoints
    func createGame(request: CreateGameRequest) async throws -> Game
    func getGame(gameId: UUID) async throws -> Game
    func getGameState(gameId: UUID) async throws -> GameState
    func joinGame(gameId: UUID, request: JoinGameRequest) async throws -> Player
    func leaveGame(gameId: UUID, request: JoinGameRequest) async throws
    func updateLife(gameId: UUID, request: UpdateLifeRequest) async throws
        -> Player
    func endGame(gameId: UUID) async throws -> Game
    func getRecentLifeChanges(gameId: UUID) async throws -> [LifeChange]
}

public protocol ConclaveWebSocketClient: Sendable {

    var isConnected: Bool { get async }
    @available(iOS 13.0, *)
    var messageStream: AsyncStream<ServerMessage> { get async }

    func connect(gameId: UUID, clerkUserId: String) async throws
    func disconnect() async

    func sendMessage(_ message: ClientMessage) async throws

    func updateLife(playerId: UUID, changeAmount: Int32) async throws
    func joinGame(clerkUserId: String) async throws
    func leaveGame(playerId: UUID) async throws
    func getGameState() async throws
    func endGame() async throws
}

public protocol ConclaveClient: ConclaveAPIClient, ConclaveWebSocketClient {
}
