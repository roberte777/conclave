import ConclaveKit
import SwiftUI

/// Reactive state manager for Conclave game sessions
///
/// Provides a high-level interface for managing game state, WebSocket connections,
/// and real-time updates. Automatically handles state synchronization and error recovery.
///
/// Features:
/// - JWT token-based authentication
/// - Observable reactive state for SwiftUI integration
/// - Automatic WebSocket connection management
/// - Real-time state updates from server messages
/// - Comprehensive error handling and recovery
@available(iOS 17.0, *)
@Observable @MainActor
public class ConclaveClientManager {

    // MARK: - Core Dependencies

    /// The underlying ConclaveKit client for API and WebSocket communication
    private let client: ConclaveClient

    /// Current authentication token
    private var authToken: String?

    // MARK: - Observable Game State

    /// Loading state for UI feedback
    public var isLoading = false

    /// Most recent error for user notification
    public var lastError: ConclaveError?

    /// Current game information
    public var currentGame: Game?

    /// All games in the database NOTE: Development testing
    public var allGames: [GameWithUsers] = []

    /// Current player (the user's player in the game)
    public var currentPlayer: Player?

    /// All players in the current game, sorted by position
    public var allPlayers: [Player] = []

    /// Recent life changes for activity feed (limited to prevent memory growth)
    public var recentLifeChanges: [LifeChange] = []

    /// Commander damage tracking
    public var commanderDamage: [CommanderDamage] = []
    
    /// Partner enabled status for each player
    public var partnerEnabled: [UUID: Bool] = [:]
    
    /// Winner of the current game (set when game ends)
    public var winner: Player?

    /// WebSocket connection status
    public var isConnectedToWebSocket = false

    // MARK: - Internal State Management

    /// Task managing the WebSocket message stream
    private var webSocketTask: Task<Void, Never>?

    // MARK: - Initialization
    public init(client: ConclaveClient) {
        self.client = client
    }

    // MARK: - Convenience Initializer
    public convenience init(baseURL: String) throws {
        let client = try ConclaveKit.createClient(baseURL: baseURL)
        self.init(client: client)
    }

    // MARK: - Authentication

    /// Set the authentication token for API and WebSocket requests
    public func setAuthToken(_ token: String?) async {
        self.authToken = token
        await client.setAuthToken(token)
    }

    // MARK: - State Management Helpers
    private func setLoading(_ loading: Bool) {
        isLoading = loading
    }

    private func handleError(_ error: Error) {
        if let conclaveError = error as? ConclaveError {
            lastError = conclaveError
        } else {
            lastError = ConclaveError.unknown(error.localizedDescription)
        }
    }

    // MARK: - Game Management

    public func getAllGames() async throws {
        setLoading(true)
        clearError()

        do {
            allGames = try await client.getAllGames()
        } catch {
            handleError(error)
        }
    }

    /// Fetches the user's active games from the backend and updates local state.
    /// This is the source of truth for whether the user has an active game.
    public func fetchUserActiveGame() async throws {
        setLoading(true)
        clearError()

        do {
            let userGames = try await client.getUserGames()
            // Find the first active game the user is in
            let activeGame = userGames.first { $0.game.status == .active }
            
            if let activeGame = activeGame {
                // User has an active game - load it
                currentGame = activeGame.game
            } else {
                // User has no active game - clear local state
                currentGame = nil
                currentPlayer = nil
            }
            
            setLoading(false)
        } catch {
            handleError(error)
            setLoading(false)
            throw error
        }
    }

    public func createGame(
        startingLife: Int32? = nil
    ) async throws -> Game {
        setLoading(true)
        clearError()

        do {
            let request = CreateGameRequest(
                startingLife: startingLife
            )
            let game = try await client.createGame(request: request)
            currentGame = game

            // Load game state to get player info (creator is automatically added as first player)
            let gameState = try await client.getGameState(gameId: game.id)
            allPlayers = gameState.players.sorted { $0.position < $1.position }
            recentLifeChanges = Array(gameState.recentChanges.prefix(10))

            // Set current player (the first player, who is the creator)
            currentPlayer = allPlayers.first

            setLoading(false)
            return game
        } catch {
            handleError(error)
            setLoading(false)
            throw error
        }
    }

    public func loadGame(gameId: UUID) async throws -> Game {
        setLoading(true)
        clearError()

        do {
            let game = try await client.getGame(gameId: gameId)
            currentGame = game
            setLoading(false)
            return game
        } catch {
            handleError(error)
            setLoading(false)
            throw error
        }
    }

    public func joinGame(gameId: UUID) async throws -> Player {
        setLoading(true)
        clearError()

        do {
            let player = try await client.joinGame(gameId: gameId)
            currentPlayer = player

            // Reload game to get updated state
            if currentGame?.id == gameId {
                _ = try await loadGame(gameId: gameId)
            }

            setLoading(false)
            return player
        } catch {
            handleError(error)
            setLoading(false)
            throw error
        }
    }

    public func leaveGame(gameId: UUID) async throws {
        setLoading(true)
        clearError()

        do {
            try await client.leaveGame(gameId: gameId)

            // Clear current player if leaving current game
            if currentGame?.id == gameId {
                currentPlayer = nil
                _ = try await loadGame(gameId: gameId)
            }

            setLoading(false)
        } catch {
            handleError(error)
            setLoading(false)
            throw error
        }
    }

    public func updateLife(gameId: UUID, playerId: UUID, changeAmount: Int32)
        async throws -> Player
    {
        setLoading(true)
        clearError()

        do {
            let request = UpdateLifeRequest(
                playerId: playerId,
                changeAmount: changeAmount
            )
            let updatedPlayer = try await client.updateLife(
                gameId: gameId,
                request: request
            )

            // Update current player if it matches
            if currentPlayer?.id == playerId {
                currentPlayer = updatedPlayer
            }

            setLoading(false)
            return updatedPlayer
        } catch {
            handleError(error)
            setLoading(false)
            throw error
        }
    }

    public func endGame(gameId: UUID, winnerPlayerId: UUID? = nil) async throws -> Game {
        setLoading(true)
        clearError()

        do {
            let game = try await client.endGame(gameId: gameId, winnerPlayerId: winnerPlayerId)

            // Update current game if it matches
            if currentGame?.id == gameId {
                currentGame = game
            }

            setLoading(false)
            return game
        } catch {
            handleError(error)
            setLoading(false)
            throw error
        }
    }

    // MARK: - WebSocket Management

    public func connectToWebSocket(gameId: UUID) async throws {
        ConclaveLogger.shared.debug(
            "connectToWebSocket called for game: \(gameId)",
            category: .websocket
        )

        guard let token = authToken else {
            throw ConclaveError.authenticationFailed("No auth token set")
        }

        // Disconnect any existing connection and wait for it to complete
        await disconnectFromWebSocketAsync()

        try await client.connect(gameId: gameId, token: token)
        isConnectedToWebSocket = await client.isConnected

        // Start listening for WebSocket messages
        startWebSocketMessageHandling()
    }

    public func disconnectFromWebSocket() {
        ConclaveLogger.shared.debug(
            "disconnectFromWebSocket called",
            category: .websocket
        )
        webSocketTask?.cancel()
        webSocketTask = nil

        Task {
            await client.disconnect()
            await MainActor.run {
                isConnectedToWebSocket = false
            }
        }
    }

    private func disconnectFromWebSocketAsync() async {
        ConclaveLogger.shared.debug(
            "disconnectFromWebSocketAsync called",
            category: .websocket
        )
        webSocketTask?.cancel()
        webSocketTask = nil

        await client.disconnect()
        isConnectedToWebSocket = false
    }

    private func startWebSocketMessageHandling() {
        webSocketTask = Task { @MainActor in
            ConclaveLogger.shared.debug(
                "WebSocket message handling task started",
                category: .websocket
            )
            let messageStream = await client.messageStream

            for await message in messageStream {
                ConclaveLogger.shared.debug(
                    "Processing message in ConclaveClientManager",
                    category: .websocket
                )
                handleWebSocketMessage(message)
                ConclaveLogger.shared.debug(
                    "Finished processing message in ConclaveClientManager",
                    category: .websocket
                )
            }

            ConclaveLogger.shared.debug(
                "WebSocket message handling task ENDED - stream finished",
                category: .websocket
            )
        }
    }

    @MainActor
    private func handleWebSocketMessage(_ message: ServerMessage) {
        switch message {
        case .lifeUpdate(let lifeUpdateMessage):
            handleLifeUpdate(lifeUpdateMessage)

        case .playerJoined(let playerJoinedMessage):
            handlePlayerJoined(playerJoinedMessage)

        case .playerLeft(let playerLeftMessage):
            handlePlayerLeft(playerLeftMessage)

        case .gameStarted(let gameStartedMessage):
            handleGameStarted(gameStartedMessage)

        case .gameEnded(let gameEndedMessage):
            handleGameEnded(gameEndedMessage)

        case .commanderDamageUpdate(let commanderDamageMessage):
            handleCommanderDamageUpdate(commanderDamageMessage)

        case .partnerToggled(let partnerMessage):
            handlePartnerToggled(partnerMessage)

        case .error(let errorMessage):
            handleWebSocketError(errorMessage)
        }
    }

    @MainActor
    private func handleLifeUpdate(_ message: LifeUpdateMessage) {
        // Update the player's life in our local state
        if let playerIndex = allPlayers.firstIndex(where: {
            $0.id == message.playerId
        }) {
            let oldPlayer = allPlayers[playerIndex]
            let oldLife = oldPlayer.currentLife

            // Create a new Player instance with updated life
            let updatedPlayer = Player(
                id: oldPlayer.id,
                gameId: oldPlayer.gameId,
                clerkUserId: oldPlayer.clerkUserId,
                currentLife: message.newLife,
                position: oldPlayer.position,
                displayName: oldPlayer.displayName,
                username: oldPlayer.username,
                imageUrl: oldPlayer.imageUrl
            )

            allPlayers[playerIndex] = updatedPlayer

            ConclaveLogger.shared.logStateChange(
                "Player life updated",
                details:
                    "Player \(message.playerId) | \(oldLife) → \(message.newLife) (\(message.changeAmount > 0 ? "+" : "")\(message.changeAmount))"
            )

            // Update currentPlayer if it's the same player
            if currentPlayer?.id == message.playerId {
                currentPlayer = updatedPlayer
            }
        }

        // Add to recent life changes
        let lifeChange = LifeChange(
            id: UUID(),
            gameId: message.gameId,
            playerId: message.playerId,
            changeAmount: message.changeAmount,
            newLifeTotal: message.newLife,
            createdAt: Date()
        )

        recentLifeChanges.insert(lifeChange, at: 0)

        // Keep only the most recent 10 changes
        if recentLifeChanges.count > 10 {
            recentLifeChanges = Array(recentLifeChanges.prefix(10))
        }
    }

    @MainActor
    private func handlePlayerJoined(_ message: PlayerJoinedMessage) {
        // Add the new player to our state
        if !allPlayers.contains(where: { $0.id == message.player.id }) {
            allPlayers.append(message.player)
            allPlayers.sort { $0.position < $1.position }

            ConclaveLogger.shared.logStateChange(
                "Player joined",
                details:
                    "Player \(message.player.id) | Position: \(message.player.position) | Life: \(message.player.currentLife)"
            )
        }
    }

    @MainActor
    private func handlePlayerLeft(_ message: PlayerLeftMessage) {
        // Remove the player from our state
        allPlayers.removeAll { $0.id == message.playerId }

        // Clear currentPlayer if they left
        if currentPlayer?.id == message.playerId {
            currentPlayer = nil
        }
    }

    @MainActor
    private func handleGameStarted(_ message: GameStartedMessage) {
        // Update game
        currentGame = message.game
        
        // Update our players list with the initial game state
        allPlayers = message.players.sorted { $0.position < $1.position }
        
        // Update commander damage
        commanderDamage = message.commanderDamage
        
        // Update recent changes
        recentLifeChanges = Array(message.recentChanges.prefix(10))
    }

    @MainActor
    private func handleGameEnded(_ message: GameEndedMessage) {
        // Set the winner
        winner = message.winner
        
        // Update game status to finished
        if var game = currentGame {
            game = Game(
                id: game.id,
                status: .finished,
                startingLife: game.startingLife,
                winnerPlayerId: message.winner?.id,
                createdAt: game.createdAt,
                finishedAt: Date()
            )
            currentGame = game
        }

        // Note: Don't disconnect automatically - let user view final state
    }

    @MainActor
    private func handleWebSocketError(_ message: ErrorMessage) {
        lastError = ConclaveError.webSocketError(message.message)
    }

    @MainActor
    private func handleCommanderDamageUpdate(
        _ message: CommanderDamageUpdateMessage
    ) {
        // Find and update existing commander damage, or create new one
        if let index = commanderDamage.firstIndex(where: {
            $0.fromPlayerId == message.fromPlayerId &&
            $0.toPlayerId == message.toPlayerId &&
            $0.commanderNumber == message.commanderNumber
        }) {
            // Update existing
            let existing = commanderDamage[index]
            commanderDamage[index] = CommanderDamage(
                id: existing.id,
                gameId: message.gameId,
                fromPlayerId: message.fromPlayerId,
                toPlayerId: message.toPlayerId,
                commanderNumber: message.commanderNumber,
                damage: message.newDamage,
                createdAt: existing.createdAt,
                updatedAt: Date()
            )
        } else {
            // Create new
            let newDamage = CommanderDamage(
                id: UUID(),
                gameId: message.gameId,
                fromPlayerId: message.fromPlayerId,
                toPlayerId: message.toPlayerId,
                commanderNumber: message.commanderNumber,
                damage: message.newDamage,
                createdAt: Date(),
                updatedAt: Date()
            )
            commanderDamage.append(newDamage)
        }
        
        ConclaveLogger.shared.logStateChange(
            "Commander damage updated",
            details:
                "From player \(message.fromPlayerId) to \(message.toPlayerId) | Commander \(message.commanderNumber) | Damage: \(message.newDamage)"
        )
    }

    @MainActor
    private func handlePartnerToggled(_ message: PartnerToggledMessage) {
        // Update partner status for the player
        partnerEnabled[message.playerId] = message.hasPartner
        
        ConclaveLogger.shared.logStateChange(
            "Partner toggled",
            details:
                "Player \(message.playerId) | Has partner: \(message.hasPartner)"
        )
    }

    // MARK: - WebSocket Actions

    public func sendLifeUpdate(playerId: UUID, changeAmount: Int32) async throws
    {
        guard isConnectedToWebSocket else {
            throw ConclaveError.notConnected
        }

        try await client.updateLife(
            playerId: playerId,
            changeAmount: changeAmount
        )
    }

    public func requestGameState() async throws {
        guard isConnectedToWebSocket else {
            throw ConclaveError.notConnected
        }

        try await client.getGameState()
    }
    
    public func sendEndGame(winnerPlayerId: UUID?) async throws {
        guard isConnectedToWebSocket else {
            throw ConclaveError.notConnected
        }
        
        try await client.endGame(winnerPlayerId: winnerPlayerId)
    }
    
    public func sendCommanderDamageUpdate(
        fromPlayerId: UUID,
        toPlayerId: UUID,
        commanderNumber: Int32,
        damageAmount: Int32
    ) async throws {
        guard isConnectedToWebSocket else {
            throw ConclaveError.notConnected
        }
        
        try await client.updateCommanderDamage(
            fromPlayerId: fromPlayerId,
            toPlayerId: toPlayerId,
            commanderNumber: commanderNumber,
            damageAmount: damageAmount
        )
    }
    
    public func sendTogglePartner(playerId: UUID, enablePartner: Bool) async throws {
        guard isConnectedToWebSocket else {
            throw ConclaveError.notConnected
        }
        
        try await client.togglePartner(playerId: playerId, enablePartner: enablePartner)
    }
    
    // MARK: - Helper Methods
    
    /// Get commander damage from a specific player to another
    public func getCommanderDamage(fromPlayerId: UUID, toPlayerId: UUID, commanderNumber: Int32) -> Int32 {
        commanderDamage.first(where: {
            $0.fromPlayerId == fromPlayerId &&
            $0.toPlayerId == toPlayerId &&
            $0.commanderNumber == commanderNumber
        })?.damage ?? 0
    }
    
    /// Get total commander damage received by a player
    public func getTotalCommanderDamage(toPlayerId: UUID) -> Int32 {
        commanderDamage
            .filter { $0.toPlayerId == toPlayerId }
            .reduce(0) { $0 + $1.damage }
    }
    
    /// Check if a player has partner enabled
    public func hasPartner(playerId: UUID) -> Bool {
        partnerEnabled[playerId] ?? false
    }

    // MARK: - Enhanced State Management

    public func loadGameWithWebSocket(gameId: UUID) async throws -> Game {
        // First load the game via HTTP
        let game = try await loadGame(gameId: gameId)

        // Then connect to WebSocket for real-time updates
        try await connectToWebSocket(gameId: gameId)

        // Load initial game state via WebSocket
        try await requestGameState()

        return game
    }

    // MARK: - Utility Methods

    public func clearCurrentGame() {
        currentGame = nil
        currentPlayer = nil
        allPlayers = []
        recentLifeChanges = []
        commanderDamage = []
        partnerEnabled = [:]
        winner = nil
        disconnectFromWebSocket()
    }

    public func clearError() {
        lastError = nil
    }

    // MARK: - Direct Client Access
    public var underlyingClient: ConclaveClient {
        // For advanced use cases where you need direct access to the underlying client
        return client
    }
}

// MARK: - Environment Key for SwiftUI
@available(iOS 17.0, *)
public struct ConclaveClientManagerKey: EnvironmentKey {
    public static let defaultValue: ConclaveClientManager? = nil
}

@available(iOS 17.0, *)
extension EnvironmentValues {
    public var conclaveClient: ConclaveClientManager? {
        get { self[ConclaveClientManagerKey.self] }
        set { self[ConclaveClientManagerKey.self] = newValue }
    }
}
