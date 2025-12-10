import Foundation

/// Mock implementation of ConclaveClient for testing and development
///
/// Features:
/// - In-memory game state simulation
/// - Realistic delay simulation
/// - WebSocket message streaming via AsyncStream
/// - Configurable behavior for testing different scenarios
@available(iOS 13.0, *)
public final class MockConclaveClient: ConclaveClient, Sendable {

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public let networkDelay: TimeInterval
        public let shouldSimulateErrors: Bool
        public let errorRate: Double  // 0.0 to 1.0

        public init(
            networkDelay: TimeInterval = 0.3,
            shouldSimulateErrors: Bool = false,
            errorRate: Double = 0.1
        ) {
            self.networkDelay = networkDelay
            self.shouldSimulateErrors = shouldSimulateErrors
            self.errorRate = errorRate
        }

        public static let `default` = Configuration()
        public static let fast = Configuration(networkDelay: 0.1)
        public static let unreliable = Configuration(
            shouldSimulateErrors: true,
            errorRate: 0.2
        )
    }

    // MARK: - Mock State

    private actor MockState {
        private var games: [UUID: Game] = [:]
        private var players: [UUID: [Player]] = [:]
        private var lifeChanges: [UUID: [LifeChange]] = [:]
        private var _isConnected = false
        private var _connectedGameId: UUID?
        private var _authToken: String?
        private var _mockUserId: String = "mock_user_\(UUID().uuidString.prefix(8))"

        // WebSocket simulation
        private var messageContinuation:
            AsyncStream<ServerMessage>.Continuation?
        private var messageStream: AsyncStream<ServerMessage>?

        init() {
            let (stream, continuation) = AsyncStream.makeStream(
                of: ServerMessage.self
            )
            self.messageStream = stream
            self.messageContinuation = continuation
        }

        func getMessageStream() -> AsyncStream<ServerMessage> {
            return messageStream ?? AsyncStream { _ in }
        }

        func broadcastMessage(_ message: ServerMessage) {
            messageContinuation?.yield(message)
        }

        func setAuthToken(_ token: String?) {
            _authToken = token
        }

        func getAuthToken() -> String? {
            return _authToken
        }

        func getMockUserId() -> String {
            return _mockUserId
        }

        func setConnected(
            _ connected: Bool,
            gameId: UUID? = nil
        ) {
            _isConnected = connected
            _connectedGameId = gameId
        }

        func isConnected() -> Bool {
            return _isConnected
        }

        func getConnectionInfo() -> UUID? {
            return _connectedGameId
        }

        func createGame(_ game: Game, creator: Player) {
            games[game.id] = game
            players[game.id] = [creator]
            lifeChanges[game.id] = []
        }

        func getGame(_ gameId: UUID) -> Game? {
            return games[gameId]
        }

        func getPlayers(_ gameId: UUID) -> [Player] {
            return players[gameId] ?? []
        }

        func getLifeChanges(_ gameId: UUID) -> [LifeChange] {
            return lifeChanges[gameId] ?? []
        }

        func addPlayer(_ player: Player, to gameId: UUID) {
            if players[gameId] == nil {
                players[gameId] = []
            }
            players[gameId]?.append(player)
        }

        func removePlayer(withId playerId: UUID, from gameId: UUID) {
            players[gameId]?.removeAll { $0.id == playerId }
        }

        func updatePlayerLife(_ playerId: UUID, in gameId: UUID, change: Int32)
            -> Player?
        {
            guard
                let playerIndex = players[gameId]?.firstIndex(where: {
                    $0.id == playerId
                })
            else {
                return nil
            }

            let oldPlayer = players[gameId]![playerIndex]
            let newLife = oldPlayer.currentLife + change

            let updatedPlayer = Player(
                id: oldPlayer.id,
                gameId: oldPlayer.gameId,
                clerkUserId: oldPlayer.clerkUserId,
                currentLife: newLife,
                position: oldPlayer.position,
                isEliminated: newLife <= 0,
                displayName: oldPlayer.displayName,
                username: oldPlayer.username,
                imageUrl: oldPlayer.imageUrl
            )

            players[gameId]![playerIndex] = updatedPlayer

            // Add life change record
            let lifeChange = LifeChange(
                id: UUID(),
                gameId: gameId,
                playerId: playerId,
                changeAmount: change,
                newLifeTotal: newLife,
                createdAt: Date()
            )

            if lifeChanges[gameId] == nil {
                lifeChanges[gameId] = []
            }
            lifeChanges[gameId]?.insert(lifeChange, at: 0)

            return updatedPlayer
        }

        func endGame(_ gameId: UUID) -> Game? {
            guard var game = games[gameId] else { return nil }

            game = Game(
                id: game.id,
                name: game.name,
                status: .finished,
                startingLife: game.startingLife,
                createdAt: game.createdAt,
                finishedAt: Date()
            )

            games[gameId] = game
            return game
        }
    }

    private let configuration: Configuration
    private let mockState = MockState()

    // MARK: - Initialization

    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    // MARK: - Utilities

    private func simulateNetworkDelay() async {
        try? await Task.sleep(
            nanoseconds: UInt64(configuration.networkDelay * 1_000_000_000)
        )
    }

    private func shouldSimulateError() -> Bool {
        return configuration.shouldSimulateErrors
            && Double.random(in: 0...1) < configuration.errorRate
    }

    private func generateMockGameId() -> UUID {
        return UUID()
    }

    private func generateMockPlayerId() -> UUID {
        return UUID()
    }

    // MARK: - Authentication

    public func setAuthToken(_ token: String?) async {
        await mockState.setAuthToken(token)
    }

    // MARK: - ConclaveAPIClient Implementation

    public func health() async throws -> HealthResponse {
        await simulateNetworkDelay()

        if shouldSimulateError() {
            throw ConclaveError.networkError(URLError(.networkConnectionLost))
        }

        return HealthResponse(status: "healthy", service: "conclave-mock")
    }

    public func stats() async throws -> StatsResponse {
        await simulateNetworkDelay()

        if shouldSimulateError() {
            throw ConclaveError.networkError(URLError(.timedOut))
        }

        return StatsResponse(
            activeGames: Int.random(in: 1...10),
            service: "conclave-mock"
        )
    }

    public func getUserHistory() async throws -> GameHistory {
        await simulateNetworkDelay()

        if shouldSimulateError() {
            throw ConclaveError.networkError(URLError(.cannotConnectToHost))
        }

        let clerkUserId = await mockState.getMockUserId()

        // Generate mock game history
        let mockGames = (0..<3).map { i in
            let gameId = generateMockGameId()
            let game = Game(
                id: gameId,
                name: "Mock Game \(i + 1)",
                status: .finished,
                startingLife: 40,
                createdAt: Date().addingTimeInterval(-Double(i * 3600)),
                finishedAt: Date().addingTimeInterval(-Double(i * 3600 - 1800))
            )

            let mockPlayers = (0..<2).map { j in
                Player(
                    id: generateMockPlayerId(),
                    gameId: gameId,
                    clerkUserId: j == 0 ? clerkUserId : "mock_opponent_\(j)",
                    currentLife: Int32.random(in: 0...40),
                    position: Int32(j + 1),
                    isEliminated: false,
                    displayName: j == 0 ? "You" : "Opponent \(j)"
                )
            }

            return GameWithPlayers(
                game: game,
                players: mockPlayers,
                winner: mockPlayers.randomElement()
            )
        }

        return GameHistory(games: mockGames)
    }

    public func getUserGames() async throws -> [GameWithUsers] {
        await simulateNetworkDelay()

        if shouldSimulateError() {
            throw ConclaveError.networkError(URLError(.timedOut))
        }

        let clerkUserId = await mockState.getMockUserId()

        // Return mock active games
        let mockGame = Game(
            id: generateMockGameId(),
            name: "Active Mock Game",
            status: .active,
            startingLife: 40,
            createdAt: Date().addingTimeInterval(-300),
            finishedAt: nil
        )

        let users = [
            UserInfo(clerkUserId: clerkUserId, displayName: "You"),
            UserInfo(clerkUserId: "mock_player_1", displayName: "Player 1"),
            UserInfo(clerkUserId: "mock_player_2", displayName: "Player 2"),
        ]

        return [GameWithUsers(game: mockGame, users: users)]
    }

    public func getAvailableGames() async throws -> [GameWithUsers] {
        await simulateNetworkDelay()

        if shouldSimulateError() {
            throw ConclaveError.networkError(URLError(.networkConnectionLost))
        }

        // Return mock available games
        let mockGame = Game(
            id: generateMockGameId(),
            name: "Available Mock Game",
            status: .active,
            startingLife: 40,
            createdAt: Date().addingTimeInterval(-600),
            finishedAt: nil
        )

        let users = [
            UserInfo(clerkUserId: "mock_host", displayName: "Host"),
            UserInfo(clerkUserId: "mock_player_1", displayName: "Player 1"),
        ]

        return [GameWithUsers(game: mockGame, users: users)]
    }

    public func getAllGames() async throws -> [GameWithUsers] {
        await simulateNetworkDelay()

        if shouldSimulateError() {
            throw ConclaveError.networkError(URLError(.networkConnectionLost))
        }

        // Return mock available games
        let mockGame1 = Game(
            id: generateMockGameId(),
            name: "Mock Game 1",
            status: .active,
            startingLife: 40,
            createdAt: Date().addingTimeInterval(-600),
            finishedAt: nil
        )

        let mockGame2 = Game(
            id: generateMockGameId(),
            name: "Mock Game 2",
            status: .active,
            startingLife: 60,
            createdAt: Date().addingTimeInterval(-800),
            finishedAt: nil
        )

        let mockGame3 = Game(
            id: generateMockGameId(),
            name: "Mock Game 3",
            status: .finished,
            startingLife: 40,
            createdAt: Date().addingTimeInterval(-800),
            finishedAt: Date()
        )

        let users1 = [
            UserInfo(clerkUserId: "mock_host", displayName: "Host"),
            UserInfo(clerkUserId: "mock_player_1", displayName: "Player 1"),
        ]

        let users2 = [
            UserInfo(clerkUserId: "mock_host", displayName: "Host"),
            UserInfo(clerkUserId: "mock_player_2", displayName: "Player 2"),
            UserInfo(clerkUserId: "mock_player_3", displayName: "Player 3"),
            UserInfo(clerkUserId: "mock_player_4", displayName: "Player 4"),
        ]

        let users3 = [
            UserInfo(clerkUserId: "mock_host", displayName: "Host"),
            UserInfo(clerkUserId: "mock_player_2", displayName: "Player 2"),
            UserInfo(clerkUserId: "mock_player_3", displayName: "Player 3"),
        ]

        return [
            GameWithUsers(game: mockGame1, users: users1),
            GameWithUsers(game: mockGame2, users: users2),
            GameWithUsers(game: mockGame3, users: users3),
        ]
    }

    public func createGame(request: CreateGameRequest) async throws -> Game {
        await simulateNetworkDelay()

        if shouldSimulateError() {
            throw ConclaveError.httpError(
                statusCode: 400,
                message: "Mock creation error"
            )
        }

        let gameId = generateMockGameId()
        let playerId = generateMockPlayerId()
        let clerkUserId = await mockState.getMockUserId()

        let game = Game(
            id: gameId,
            name: request.name,
            status: .active,
            startingLife: request.startingLife ?? 40,
            createdAt: Date(),
            finishedAt: nil
        )

        let creator = Player(
            id: playerId,
            gameId: gameId,
            clerkUserId: clerkUserId,
            currentLife: game.startingLife,
            position: 1,
            isEliminated: false,
            displayName: "You"
        )

        await mockState.createGame(game, creator: creator)

        return game
    }

    public func getGame(gameId: UUID) async throws -> Game {
        await simulateNetworkDelay()

        if shouldSimulateError() {
            throw ConclaveError.networkError(URLError(.timedOut))
        }

        guard let game = await mockState.getGame(gameId) else {
            throw ConclaveError.gameNotFound("Game with ID \(gameId) not found")
        }

        return game
    }

    public func getGameState(gameId: UUID) async throws -> GameState {
        await simulateNetworkDelay()

        if shouldSimulateError() {
            throw ConclaveError.networkError(URLError(.cannotConnectToHost))
        }

        guard let game = await mockState.getGame(gameId) else {
            throw ConclaveError.gameNotFound("Game with ID \(gameId) not found")
        }

        let players = await mockState.getPlayers(gameId)
        let recentChanges = await mockState.getLifeChanges(gameId)

        return GameState(
            game: game,
            players: players,
            recentChanges: Array(recentChanges.prefix(10)),
            commanderDamage: []  // Mock empty commander damage array
        )
    }

    public func joinGame(gameId: UUID) async throws -> Player {
        await simulateNetworkDelay()

        if shouldSimulateError() {
            throw ConclaveError.httpError(
                statusCode: 400,
                message: "Mock join error"
            )
        }

        guard let game = await mockState.getGame(gameId) else {
            throw ConclaveError.gameNotFound("Game with ID \(gameId) not found")
        }

        let clerkUserId = await mockState.getMockUserId()
        let existingPlayers = await mockState.getPlayers(gameId)

        // Check if player already exists
        if let existingPlayer = existingPlayers.first(where: {
            $0.clerkUserId == clerkUserId
        }) {
            return existingPlayer
        }

        let playerId = generateMockPlayerId()
        let position = Int32(existingPlayers.count + 1)

        let player = Player(
            id: playerId,
            gameId: gameId,
            clerkUserId: clerkUserId,
            currentLife: game.startingLife,
            position: position,
            isEliminated: false,
            displayName: "You"
        )

        await mockState.addPlayer(player, to: gameId)

        // Broadcast player joined via WebSocket
        if await mockState.isConnected() {
            let message = PlayerJoinedMessage(gameId: gameId, player: player)
            await mockState.broadcastMessage(.playerJoined(message))
        }

        return player
    }

    public func leaveGame(gameId: UUID) async throws {
        await simulateNetworkDelay()

        if shouldSimulateError() {
            throw ConclaveError.networkError(URLError(.networkConnectionLost))
        }

        let clerkUserId = await mockState.getMockUserId()
        let players = await mockState.getPlayers(gameId)
        guard
            let player = players.first(where: {
                $0.clerkUserId == clerkUserId
            })
        else {
            throw ConclaveError.playerNotFound(
                "Player with Clerk user ID \(clerkUserId) not found"
            )
        }

        await mockState.removePlayer(withId: player.id, from: gameId)

        // Broadcast player left via WebSocket
        if await mockState.isConnected() {
            let message = PlayerLeftMessage(gameId: gameId, playerId: player.id)
            await mockState.broadcastMessage(.playerLeft(message))
        }
    }

    public func updateLife(gameId: UUID, request: UpdateLifeRequest)
        async throws -> Player
    {
        await simulateNetworkDelay()

        if shouldSimulateError() {
            throw ConclaveError.networkError(URLError(.timedOut))
        }

        guard
            let updatedPlayer = await mockState.updatePlayerLife(
                request.playerId,
                in: gameId,
                change: request.changeAmount
            )
        else {
            throw ConclaveError.playerNotFound(
                "Player with ID \(request.playerId) not found"
            )
        }

        return updatedPlayer
    }

    public func endGame(gameId: UUID) async throws -> Game {
        await simulateNetworkDelay()

        if shouldSimulateError() {
            throw ConclaveError.networkError(URLError(.cannotConnectToHost))
        }

        guard let endedGame = await mockState.endGame(gameId) else {
            throw ConclaveError.gameNotFound("Game with ID \(gameId) not found")
        }

        // Broadcast game ended via WebSocket
        if await mockState.isConnected() {
            let players = await mockState.getPlayers(gameId)
            let winner = players.max(by: { $0.currentLife < $1.currentLife })
            let message = GameEndedMessage(gameId: gameId, winner: winner)
            await mockState.broadcastMessage(.gameEnded(message))
        }

        return endedGame
    }

    public func getRecentLifeChanges(gameId: UUID) async throws -> [LifeChange]
    {
        await simulateNetworkDelay()

        if shouldSimulateError() {
            throw ConclaveError.networkError(URLError(.timedOut))
        }

        let changes = await mockState.getLifeChanges(gameId)
        return Array(changes.prefix(20))
    }

    // MARK: - Commander Damage API Implementation

    public func updateCommanderDamage(
        gameId: UUID,
        request: UpdateCommanderDamageRequest
    ) async throws -> CommanderDamage {
        await simulateNetworkDelay()

        if shouldSimulateError() {
            throw ConclaveError.networkError(URLError(.timedOut))
        }

        // Create mock commander damage
        let commanderDamage = CommanderDamage(
            id: UUID(),
            gameId: gameId,
            fromPlayerId: request.fromPlayerId,
            toPlayerId: request.toPlayerId,
            commanderNumber: request.commanderNumber,
            damage: request.damageAmount,
            createdAt: Date(),
            updatedAt: Date()
        )

        return commanderDamage
    }

    public func togglePartner(
        gameId: UUID,
        playerId: UUID,
        request: TogglePartnerRequest
    ) async throws {
        await simulateNetworkDelay()

        if shouldSimulateError() {
            throw ConclaveError.networkError(URLError(.timedOut))
        }

        // Mock implementation - in real app this would update the player's partner status
    }

    // MARK: - ConclaveWebSocketClient Implementation

    public var isConnected: Bool {
        get async {
            return await mockState.isConnected()
        }
    }

    public var messageStream: AsyncStream<ServerMessage> {
        get async {
            return await mockState.getMessageStream()
        }
    }

    public func connect(gameId: UUID, token: String) async throws {
        await simulateNetworkDelay()

        if shouldSimulateError() {
            throw ConclaveError.webSocketError("Mock connection error")
        }

        await mockState.setConnected(true, gameId: gameId)

        // Send initial game state
        do {
            let gameState = try await getGameState(gameId: gameId)
            let message = GameStartedMessage(
                game: gameState.game,
                players: gameState.players,
                recentChanges: gameState.recentChanges,
                commanderDamage: gameState.commanderDamage
            )
            await mockState.broadcastMessage(.gameStarted(message))
        } catch {
            // Ignore errors for mock initial state
        }
    }

    public func disconnect() async {
        await mockState.setConnected(false)
    }

    public func sendMessage(_ message: ClientMessage) async throws {
        await simulateNetworkDelay()

        if shouldSimulateError() {
            throw ConclaveError.webSocketError("Mock send error")
        }

        guard let gameId = await mockState.getConnectionInfo() else {
            throw ConclaveError.notConnected
        }

        // Process the message and generate appropriate responses
        switch message {
        case .updateLife(let playerId, let changeAmount):
            try await handleMockLifeUpdate(
                gameId: gameId,
                playerId: playerId,
                changeAmount: changeAmount
            )
        case .leaveGame(let playerId):
            try await handleMockLeaveGame(gameId: gameId, playerId: playerId)
        case .getGameState:
            try await handleMockGetGameState(gameId: gameId)
        case .endGame:
            try await handleMockEndGame(gameId: gameId)
        case .setCommanderDamage(
            let fromPlayerId,
            let toPlayerId,
            let commanderNumber,
            let newDamage
        ):
            try await handleMockSetCommanderDamage(
                gameId: gameId,
                fromPlayerId: fromPlayerId,
                toPlayerId: toPlayerId,
                commanderNumber: commanderNumber,
                newDamage: newDamage
            )
        case .updateCommanderDamage(
            let fromPlayerId,
            let toPlayerId,
            let commanderNumber,
            let damageAmount
        ):
            try await handleMockUpdateCommanderDamage(
                gameId: gameId,
                fromPlayerId: fromPlayerId,
                toPlayerId: toPlayerId,
                commanderNumber: commanderNumber,
                damageAmount: damageAmount
            )
        case .togglePartner(let playerId, let enablePartner):
            try await handleMockTogglePartner(
                gameId: gameId,
                playerId: playerId,
                enablePartner: enablePartner
            )
        }
    }

    public func updateLife(playerId: UUID, changeAmount: Int32) async throws {
        let message = ClientMessage.updateLife(
            playerId: playerId,
            changeAmount: changeAmount
        )
        try await sendMessage(message)
    }

    public func leaveGame(playerId: UUID) async throws {
        let message = ClientMessage.leaveGame(playerId: playerId)
        try await sendMessage(message)
    }

    public func getGameState() async throws {
        let message = ClientMessage.getGameState
        try await sendMessage(message)
    }

    public func endGame() async throws {
        let message = ClientMessage.endGame
        try await sendMessage(message)
    }

    // MARK: - Commander Damage WebSocket Implementation

    public func setCommanderDamage(
        fromPlayerId: UUID,
        toPlayerId: UUID,
        commanderNumber: Int32,
        newDamage: Int32
    ) async throws {
        let message = ClientMessage.setCommanderDamage(
            fromPlayerId: fromPlayerId,
            toPlayerId: toPlayerId,
            commanderNumber: commanderNumber,
            newDamage: newDamage
        )
        try await sendMessage(message)
    }

    public func updateCommanderDamage(
        fromPlayerId: UUID,
        toPlayerId: UUID,
        commanderNumber: Int32,
        damageAmount: Int32
    ) async throws {
        let message = ClientMessage.updateCommanderDamage(
            fromPlayerId: fromPlayerId,
            toPlayerId: toPlayerId,
            commanderNumber: commanderNumber,
            damageAmount: damageAmount
        )
        try await sendMessage(message)
    }

    public func togglePartner(playerId: UUID, enablePartner: Bool) async throws
    {
        let message = ClientMessage.togglePartner(
            playerId: playerId,
            enablePartner: enablePartner
        )
        try await sendMessage(message)
    }

    // MARK: - Mock WebSocket Message Handlers

    private func handleMockLifeUpdate(
        gameId: UUID,
        playerId: UUID,
        changeAmount: Int32
    ) async throws {
        guard
            let updatedPlayer = await mockState.updatePlayerLife(
                playerId,
                in: gameId,
                change: changeAmount
            )
        else {
            throw ConclaveError.playerNotFound(
                "Player with ID \(playerId) not found"
            )
        }

        let message = LifeUpdateMessage(
            gameId: gameId,
            playerId: playerId,
            newLife: updatedPlayer.currentLife,
            changeAmount: changeAmount
        )

        await mockState.broadcastMessage(.lifeUpdate(message))
    }

    private func handleMockLeaveGame(gameId: UUID, playerId: UUID) async throws
    {
        let players = await mockState.getPlayers(gameId)
        guard let player = players.first(where: { $0.id == playerId }) else {
            throw ConclaveError.playerNotFound(
                "Player with ID \(playerId) not found"
            )
        }

        await mockState.removePlayer(withId: player.id, from: gameId)

        // Broadcast player left via WebSocket
        if await mockState.isConnected() {
            let message = PlayerLeftMessage(gameId: gameId, playerId: player.id)
            await mockState.broadcastMessage(.playerLeft(message))
        }
    }

    private func handleMockGetGameState(gameId: UUID) async throws {
        let gameState = try await getGameState(gameId: gameId)
        let message = GameStartedMessage(
            game: gameState.game,
            players: gameState.players,
            recentChanges: gameState.recentChanges,
            commanderDamage: gameState.commanderDamage
        )
        await mockState.broadcastMessage(.gameStarted(message))
    }

    private func handleMockEndGame(gameId: UUID) async throws {
        _ = try await endGame(gameId: gameId)
    }

    private func handleMockSetCommanderDamage(
        gameId: UUID,
        fromPlayerId: UUID,
        toPlayerId: UUID,
        commanderNumber: Int32,
        newDamage: Int32
    ) async throws {
        // Create mock commander damage message
        let message = CommanderDamageUpdateMessage(
            gameId: gameId,
            fromPlayerId: fromPlayerId,
            toPlayerId: toPlayerId,
            commanderNumber: commanderNumber,
            newDamage: newDamage,
            damageAmount: 0  // Set damage for "set" operation
        )
        await mockState.broadcastMessage(.commanderDamageUpdate(message))
    }

    private func handleMockUpdateCommanderDamage(
        gameId: UUID,
        fromPlayerId: UUID,
        toPlayerId: UUID,
        commanderNumber: Int32,
        damageAmount: Int32
    ) async throws {
        // Create mock commander damage message
        let message = CommanderDamageUpdateMessage(
            gameId: gameId,
            fromPlayerId: fromPlayerId,
            toPlayerId: toPlayerId,
            commanderNumber: commanderNumber,
            newDamage: damageAmount,  // For updates, this would be calculated
            damageAmount: damageAmount
        )
        await mockState.broadcastMessage(.commanderDamageUpdate(message))
    }

    private func handleMockTogglePartner(
        gameId: UUID,
        playerId: UUID,
        enablePartner: Bool
    ) async throws {
        // Create mock partner toggle message
        let message = PartnerToggledMessage(
            gameId: gameId,
            playerId: playerId,
            hasPartner: enablePartner
        )
        await mockState.broadcastMessage(.partnerToggled(message))
    }
}

// MARK: - Mock Extensions

extension MockConclaveClient {

    /// Create a mock client optimized for testing
    public static var testing: MockConclaveClient {
        return MockConclaveClient(configuration: .fast)
    }

    /// Create a mock client that simulates network issues
    public static var unreliable: MockConclaveClient {
        return MockConclaveClient(configuration: .unreliable)
    }

    /// Create a mock client with custom configuration
    public static func custom(
        delay: TimeInterval = 0.3,
        simulateErrors: Bool = false,
        errorRate: Double = 0.1
    ) -> MockConclaveClient {
        let config = Configuration(
            networkDelay: delay,
            shouldSimulateErrors: simulateErrors,
            errorRate: errorRate
        )
        return MockConclaveClient(configuration: config)
    }
}
