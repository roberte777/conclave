import Foundation

/// Protocol for authenticated API clients that require a token
public protocol ConclaveAPIClient: Sendable {

    /// Set the authentication token for API requests
    func setAuthToken(_ token: String?) async

    // MARK: - Health & Stats
    func health() async throws -> HealthResponse
    func stats() async throws -> StatsResponse

    // MARK: - User Endpoints (authenticated, uses /users/me/)
    func getUserHistory() async throws -> GameHistory
    func getUserGames() async throws -> [GameWithUsers]
    func getAvailableGames() async throws -> [GameWithUsers]
    func getAllGames() async throws -> [GameWithUsers]

    // MARK: - Game Endpoints
    func createGame(request: CreateGameRequest) async throws -> Game
    func getGame(gameId: UUID) async throws -> Game
    func getGameState(gameId: UUID) async throws -> GameState
    func joinGame(gameId: UUID) async throws -> Player
    func leaveGame(gameId: UUID) async throws
    func updateLife(gameId: UUID, request: UpdateLifeRequest) async throws
        -> Player
    func endGame(gameId: UUID) async throws -> Game
    func getRecentLifeChanges(gameId: UUID) async throws -> [LifeChange]

    // MARK: - Commander Damage Endpoints
    func updateCommanderDamage(
        gameId: UUID,
        request: UpdateCommanderDamageRequest
    ) async throws -> CommanderDamage
    func togglePartner(
        gameId: UUID,
        playerId: UUID,
        request: TogglePartnerRequest
    ) async throws
}

public protocol ConclaveWebSocketClient: Sendable {

    var isConnected: Bool { get async }
    @available(iOS 13.0, *)
    var messageStream: AsyncStream<ServerMessage> { get async }

    /// Connect to WebSocket with JWT token (user is automatically joined to game)
    func connect(gameId: UUID, token: String) async throws
    func disconnect() async

    func sendMessage(_ message: ClientMessage) async throws

    func updateLife(playerId: UUID, changeAmount: Int32) async throws
    func leaveGame(playerId: UUID) async throws
    func getGameState() async throws
    func endGame() async throws

    // MARK: - Commander Damage WebSocket Methods
    func setCommanderDamage(
        fromPlayerId: UUID,
        toPlayerId: UUID,
        commanderNumber: Int32,
        newDamage: Int32
    ) async throws
    func updateCommanderDamage(
        fromPlayerId: UUID,
        toPlayerId: UUID,
        commanderNumber: Int32,
        damageAmount: Int32
    ) async throws
    func togglePartner(playerId: UUID, enablePartner: Bool) async throws
}

public protocol ConclaveClient: ConclaveAPIClient, ConclaveWebSocketClient {
}
