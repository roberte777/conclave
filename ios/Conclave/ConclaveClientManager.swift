import ConclaveKit
import SwiftUI

/// Reactive state manager for Conclave game sessions
///
/// Provides a high-level interface for managing game state, WebSocket connections,
/// and real-time updates. Automatically handles state synchronization and error recovery.
///
/// Features:
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

    // MARK: - Observable Game State

    /// Loading state for UI feedback
    public var isLoading = false

    /// Most recent error for user notification
    public var lastError: ConclaveError?

    /// Current game information
    public var currentGame: Game?

    /// Current player (the user's player in the game)
    public var currentPlayer: Player?

    /// All players in the current game, sorted by position
    public var allPlayers: [Player] = []

    /// Recent life changes for activity feed (limited to prevent memory growth)
    public var recentLifeChanges: [LifeChange] = []

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

    public func createGame(
        name: String,
        startingLife: Int32? = nil,
        clerkUserId: String
    ) async throws -> Game {
        setLoading(true)
        clearError()

        do {
            let request = CreateGameRequest(
                name: name,
                startingLife: startingLife,
                clerkUserId: clerkUserId
            )
            let game = try await client.createGame(request: request)
            currentGame = game

            // Load game state to get player info (creator is automatically added as first player)
            let gameState = try await client.getGameState(gameId: game.id)
            allPlayers = gameState.players.sorted { $0.position < $1.position }
            recentLifeChanges = Array(gameState.recentChanges.prefix(10))

            // Set current player (the creator)
            currentPlayer = allPlayers.first { $0.clerkUserId == clerkUserId }

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

    public func joinGame(gameId: UUID, clerkUserId: String) async throws
        -> Player
    {
        setLoading(true)
        clearError()

        do {
            let request = JoinGameRequest(clerkUserId: clerkUserId)
            let player = try await client.joinGame(
                gameId: gameId,
                request: request
            )
            currentPlayer = player

            // Reload game to get updated state
            if currentGame?.id == gameId {
                try await loadGame(gameId: gameId)
            }

            setLoading(false)
            return player
        } catch {
            handleError(error)
            setLoading(false)
            throw error
        }
    }

    public func leaveGame(gameId: UUID, clerkUserId: String) async throws {
        setLoading(true)
        clearError()

        do {
            let request = JoinGameRequest(clerkUserId: clerkUserId)
            try await client.leaveGame(gameId: gameId, request: request)

            // Clear current player if leaving current game
            if currentGame?.id == gameId {
                currentPlayer = nil
                try await loadGame(gameId: gameId)
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

    public func endGame(gameId: UUID) async throws -> Game {
        setLoading(true)
        clearError()

        do {
            let game = try await client.endGame(gameId: gameId)

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

    public func connectToWebSocket(gameId: UUID, clerkUserId: String)
        async throws
    {
        ConclaveLogger.shared.debug(
            "connectToWebSocket called for game: \(gameId)",
            category: .websocket
        )
        // Disconnect any existing connection and wait for it to complete
        await disconnectFromWebSocketAsync()

        try await client.connect(gameId: gameId, clerkUserId: clerkUserId)
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
                isEliminated: oldPlayer.isEliminated
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
        // Update our players list with the initial game state
        allPlayers = message.players.sorted { $0.position < $1.position }
    }

    @MainActor
    private func handleGameEnded(_ message: GameEndedMessage) {
        // Update game status to finished
        if var game = currentGame {
            game = Game(
                id: game.id,
                name: game.name,
                status: .finished,
                startingLife: game.startingLife,
                createdAt: game.createdAt,
                finishedAt: game.finishedAt
            )
            currentGame = game
        }

        // Disconnect from WebSocket since game is over
        disconnectFromWebSocket()
    }

    @MainActor
    private func handleWebSocketError(_ message: ErrorMessage) {
        lastError = ConclaveError.webSocketError(message.message)
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

    // MARK: - Enhanced State Management

    public func loadGameWithWebSocket(gameId: UUID, clerkUserId: String)
        async throws -> Game
    {
        // First load the game via HTTP
        let game = try await loadGame(gameId: gameId)

        // Then connect to WebSocket for real-time updates
        try await connectToWebSocket(gameId: gameId, clerkUserId: clerkUserId)

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
