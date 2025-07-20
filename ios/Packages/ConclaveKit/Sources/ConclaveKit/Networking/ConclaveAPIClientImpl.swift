import Foundation

@available(iOS 18.0, *)
public final class ConclaveAPIClientImpl: ConclaveClient, Sendable {

    private let httpClient: HTTPClient
    private let webSocketClient: WebSocketClient

    public init(baseURL: URL, session: URLSession = .shared) {
        self.httpClient = HTTPClient(baseURL: baseURL, session: session)
        self.webSocketClient = WebSocketClient(
            baseURL: baseURL,
            session: session
        )
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

    // MARK: - ConclaveAPIClient Implementation

    public func health() async throws -> HealthResponse {
        try await httpClient.health()
    }

    public func stats() async throws -> StatsResponse {
        try await httpClient.stats()
    }

    public func getUserHistory(clerkUserId: String) async throws -> GameHistory
    {
        try await httpClient.getUserHistory(clerkUserId: clerkUserId)
    }

    public func getUserGames(clerkUserId: String) async throws
        -> [GameWithUsers]
    {
        try await httpClient.getUserGames(clerkUserId: clerkUserId)
    }

    public func getAvailableGames(clerkUserId: String) async throws
        -> [GameWithUsers]
    {
        try await httpClient.getAvailableGames(clerkUserId: clerkUserId)
    }

    public func createGame(request: CreateGameRequest) async throws -> Game {
        try await httpClient.createGame(request: request)
    }

    public func getGame(gameId: UUID) async throws -> Game {
        try await httpClient.getGame(gameId: gameId)
    }

    public func getGameState(gameId: UUID) async throws -> GameState {
        try await httpClient.getGameState(gameId: gameId)
    }

    public func joinGame(gameId: UUID, request: JoinGameRequest) async throws
        -> Player
    {
        try await httpClient.joinGame(gameId: gameId, request: request)
    }

    public func leaveGame(gameId: UUID, request: JoinGameRequest) async throws {
        try await httpClient.leaveGame(gameId: gameId, request: request)
    }

    public func updateLife(gameId: UUID, request: UpdateLifeRequest)
        async throws -> Player
    {
        try await httpClient.updateLife(gameId: gameId, request: request)
    }

    public func endGame(gameId: UUID) async throws -> Game {
        try await httpClient.endGame(gameId: gameId)
    }

    public func getRecentLifeChanges(gameId: UUID) async throws -> [LifeChange]
    {
        try await httpClient.getRecentLifeChanges(gameId: gameId)
    }

    // MARK: - Commander Damage API Implementation
    
    public func updateCommanderDamage(gameId: UUID, request: UpdateCommanderDamageRequest) async throws -> CommanderDamage {
        try await httpClient.updateCommanderDamage(gameId: gameId, request: request)
    }
    
    public func togglePartner(gameId: UUID, playerId: UUID, request: TogglePartnerRequest) async throws {
        try await httpClient.togglePartner(gameId: gameId, playerId: playerId, request: request)
    }

    // MARK: - ConclaveWebSocketClient Implementation

    public var isConnected: Bool {
        get async {
            await webSocketClient.isConnected
        }
    }

    public var messageStream: AsyncStream<ServerMessage> {
        get async {
            await webSocketClient.messageStream
        }
    }

    public func connect(gameId: UUID, clerkUserId: String) async throws {
        try await webSocketClient.connect(
            gameId: gameId,
            clerkUserId: clerkUserId
        )
    }

    public func disconnect() async {
        await webSocketClient.disconnect()
    }

    public func sendMessage(_ message: ClientMessage) async throws {
        try await webSocketClient.sendMessage(message)
    }

    public func updateLife(playerId: UUID, changeAmount: Int32) async throws {
        try await webSocketClient.updateLife(
            playerId: playerId,
            changeAmount: changeAmount
        )
    }

    public func joinGame(clerkUserId: String) async throws {
        try await webSocketClient.joinGame(clerkUserId: clerkUserId)
    }

    public func leaveGame(playerId: UUID) async throws {
        try await webSocketClient.leaveGame(playerId: playerId)
    }

    public func getGameState() async throws {
        try await webSocketClient.getGameState()
    }

    public func endGame() async throws {
        try await webSocketClient.endGame()
    }

    // MARK: - Commander Damage WebSocket Implementation
    
    public func setCommanderDamage(fromPlayerId: UUID, toPlayerId: UUID, commanderNumber: Int32, newDamage: Int32) async throws {
        try await webSocketClient.setCommanderDamage(fromPlayerId: fromPlayerId, toPlayerId: toPlayerId, commanderNumber: commanderNumber, newDamage: newDamage)
    }
    
    public func updateCommanderDamage(fromPlayerId: UUID, toPlayerId: UUID, commanderNumber: Int32, damageAmount: Int32) async throws {
        try await webSocketClient.updateCommanderDamage(fromPlayerId: fromPlayerId, toPlayerId: toPlayerId, commanderNumber: commanderNumber, damageAmount: damageAmount)
    }
    
    public func togglePartner(playerId: UUID, enablePartner: Bool) async throws {
        try await webSocketClient.togglePartner(playerId: playerId, enablePartner: enablePartner)
    }
}
