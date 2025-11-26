import Foundation

/// High-performance WebSocket client with automatic reconnection and message buffering
///
/// Features:
/// - Actor-based concurrency safety
/// - Automatic reconnection with exponential backoff
/// - Circular message buffer for recent message retrieval
/// - Comprehensive error handling and logging
@available(iOS 18.0, *)
public final class WebSocketClient: ConclaveWebSocketClient, Sendable {

    // MARK: - Core Properties

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // MARK: - Message Streaming

    /// Actor to manage message streaming state for concurrency safety
    private actor MessageStreamManager {
        private var continuation: AsyncStream<ServerMessage>.Continuation?
        private var stream: AsyncStream<ServerMessage>?

        func createNewStream() -> AsyncStream<ServerMessage> {
            let (newStream, newContinuation) = AsyncStream.makeStream(
                of: ServerMessage.self
            )
            stream = newStream
            continuation = newContinuation
            ConclaveLogger.shared.debug(
                "Created new message stream",
                category: .websocket
            )
            return newStream
        }

        func getCurrentStream() -> AsyncStream<ServerMessage>? {
            if stream != nil {
                ConclaveLogger.shared.debug(
                    "Returning existing message stream",
                    category: .websocket
                )
            } else {
                ConclaveLogger.shared.debug(
                    "No message stream available",
                    category: .websocket
                )
            }
            return stream
        }

        func yieldMessage(_ message: ServerMessage) {
            continuation?.yield(message)
        }

        func finishStream() {
            continuation?.finish()
            continuation = nil
            stream = nil
            ConclaveLogger.shared.debug(
                "Message stream finished and cleared",
                category: .websocket
            )
        }
    }

    private let messageStreamManager = MessageStreamManager()

    /// Circular buffer for recent messages - automatically manages memory by overwriting old messages
    private let messageBuffer = SynchronizedCircularBuffer<ServerMessage>(
        capacity: 100
    )

    /// Actor-isolated connection management for thread safety
    /// Manages WebSocket lifecycle, reconnection logic, and connection state
    private actor ConnectionManager {
        private var _isConnected = false
        private var _webSocketTask: URLSessionWebSocketTask?

        // Connection info for reconnection
        private var _gameId: UUID?
        private var _token: String?

        // Reconnection management with exponential backoff
        private var _reconnectAttempts = 0
        private var _maxReconnectAttempts = 5
        private var _reconnectDelay: TimeInterval = 1.0
        private var _isReconnecting = false

        func setConnected(_ connected: Bool) {
            _isConnected = connected
            if connected {
                _reconnectAttempts = 0
                _isReconnecting = false
            }
        }

        func isConnected() -> Bool {
            return _isConnected
        }

        func setWebSocketTask(_ task: URLSessionWebSocketTask?) {
            _webSocketTask = task
        }

        func getWebSocketTask() -> URLSessionWebSocketTask? {
            return _webSocketTask
        }

        func setConnectionInfo(gameId: UUID, token: String) {
            _gameId = gameId
            _token = token
        }

        func getConnectionInfo() -> (gameId: UUID, token: String)? {
            guard let gameId = _gameId, let token = _token else {
                ConclaveLogger.shared.debug(
                    "getConnectionInfo returning nil - gameId: \(_gameId?.uuidString ?? "nil"), token: \(_token != nil ? "[set]" : "nil")",
                    category: .websocket
                )
                return nil
            }
            ConclaveLogger.shared.debug(
                "getConnectionInfo returning - gameId: \(gameId.uuidString), token: [set]",
                category: .websocket
            )
            return (gameId, token)
        }

        func shouldReconnect() -> Bool {
            return !_isConnected && !_isReconnecting
                && _reconnectAttempts < _maxReconnectAttempts
        }

        func startReconnecting() {
            _isReconnecting = true
            _reconnectAttempts += 1
        }

        func getReconnectDelay() -> TimeInterval {
            // Exponential backoff with jitter
            let delay = min(
                _reconnectDelay * pow(2.0, Double(_reconnectAttempts - 1)),
                30.0
            )
            let jitter = Double.random(in: 0.8...1.2)
            return delay * jitter
        }

        func disconnect() {
            _webSocketTask?.cancel(with: .normalClosure, reason: nil)
            _webSocketTask = nil
            _isConnected = false
            _isReconnecting = false
        }

        func reset() {
            ConclaveLogger.shared.debug(
                "Resetting connection info",
                category: .websocket
            )
            disconnect()
            _gameId = nil
            _token = nil
            _reconnectAttempts = 0
        }

        func disconnectWithoutReset() {
            // Disconnect but keep connection info for potential reconnection
            _webSocketTask?.cancel(with: .normalClosure, reason: nil)
            _webSocketTask = nil
            _isConnected = false
            _isReconnecting = false
        }

        func disconnectForReconnection() {
            // Disconnect for reconnection - keep connection info AND don't reset stream
            _webSocketTask?.cancel(with: .normalClosure, reason: nil)
            _webSocketTask = nil
            _isConnected = false
            _isReconnecting = false
        }
    }

    private let connectionManager = ConnectionManager()

    public var isConnected: Bool {
        get async {
            await connectionManager.isConnected()
        }
    }

    public var messageStream: AsyncStream<ServerMessage> {
        get async {
            guard let stream = await messageStreamManager.getCurrentStream()
            else {
                // This should only happen if accessed before connection
                ConclaveLogger.shared.warning(
                    "messageStream accessed before connection established",
                    category: .websocket
                )
                return await messageStreamManager.createNewStream()
            }
            return stream
        }
    }

    /// Get the most recent messages from the buffer (useful for catching up)
    public func getRecentMessages(count: Int = 10) -> [ServerMessage] {
        return messageBuffer.recent(count)
    }

    /// Clear the message buffer
    public func clearMessageBuffer() {
        messageBuffer.removeAll()
    }

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .useDefaultKeys  // WebSocket protocol specifies camelCase
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
        self.encoder.keyEncodingStrategy = .useDefaultKeys  // WebSocket protocol uses camelCase
        self.encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [
                .withInternetDateTime, .withFractionalSeconds,
            ]
            let dateString = formatter.string(from: date)
            var container = encoder.singleValueContainer()
            try container.encode(dateString)
        }

        // Message stream will be created when first accessed
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

    // MARK: - Connection Management

    public func connect(gameId: UUID, token: String) async throws {
        guard !(await connectionManager.isConnected()) else {
            ConclaveLogger.shared.debug(
                "WebSocket already connected",
                category: .websocket
            )
            return
        }

        ConclaveLogger.shared.logWebSocketEvent(
            "Connecting",
            gameId: gameId,
            details: "With JWT token"
        )
        await connectionManager.setConnectionInfo(
            gameId: gameId,
            token: token
        )

        // Create a fresh message stream for this connection
        _ = await messageStreamManager.createNewStream()

        try await performConnection()
    }

    private func performConnection() async throws {
        guard let connectionInfo = await connectionManager.getConnectionInfo()
        else {
            throw ConclaveError.connectionFailed("No connection info available")
        }

        var components = URLComponents(
            url: baseURL,
            resolvingAgainstBaseURL: false
        )
        components?.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        components?.path = "/ws"
        components?.queryItems = [
            URLQueryItem(
                name: "gameId",
                value: connectionInfo.gameId.uuidString
            ),
            URLQueryItem(
                name: "token",
                value: connectionInfo.token
            ),
        ]

        guard let wsURL = components?.url else {
            throw ConclaveError.invalidURL("Failed to construct WebSocket URL")
        }

        let task = session.webSocketTask(with: wsURL)
        await connectionManager.setWebSocketTask(task)
        task.resume()

        await connectionManager.setConnected(true)

        ConclaveLogger.shared.logWebSocketEvent(
            "Connected",
            gameId: connectionInfo.gameId
        )

        Task {
            await startListening()
        }
    }

    public func disconnect() async {
        ConclaveLogger.shared.logWebSocketEvent("Disconnecting")
        ConclaveLogger.shared.debug(
            "disconnect() called - stack trace will help identify caller",
            category: .websocket
        )
        await connectionManager.reset()

        // Finish the current stream and clear it so a new one can be created
        await messageStreamManager.finishStream()
    }

    // MARK: - Message Sending

    public func sendMessage(_ message: ClientMessage) async throws {
        guard await connectionManager.isConnected(),
            let webSocketTask = await connectionManager.getWebSocketTask()
        else {
            throw ConclaveError.notConnected
        }

        do {
            let data = try encoder.encode(message)
            let string = String(data: data, encoding: .utf8)!
            ConclaveLogger.shared.debug(
                "Sending WebSocket message: \(string)",
                category: .websocket
            )
            try await webSocketTask.send(.string(string))
        } catch {
            ConclaveLogger.shared.error(
                "Failed to send WebSocket message: \(error.localizedDescription)",
                category: .websocket
            )
            throw ConclaveError.encodingError(error.localizedDescription)
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

    // MARK: - Commander Damage WebSocket Methods

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

    // MARK: - Private Methods

    private func startListening() async {
        guard let webSocketTask = await connectionManager.getWebSocketTask()
        else { return }

        do {
            while await connectionManager.isConnected() {
                let message = try await webSocketTask.receive()
                await handleMessage(message)
            }
        } catch {
            await connectionManager.disconnectWithoutReset()
            ConclaveLogger.shared.error(
                "WebSocket listening error: \(error.localizedDescription)",
                category: .websocket
            )

            let errorMessage = ErrorMessage(message: error.localizedDescription)
            await messageStreamManager.yieldMessage(.error(errorMessage))

            // Attempt reconnection if appropriate
            await attemptReconnection()
        }
    }

    private func attemptReconnection() async {
        guard await connectionManager.shouldReconnect() else {
            ConclaveLogger.shared.warning(
                "Reconnection not attempted - max attempts reached or conditions not met",
                category: .websocket
            )
            return
        }

        await connectionManager.startReconnecting()
        let delay = await connectionManager.getReconnectDelay()

        ConclaveLogger.shared.logWebSocketEvent(
            "Reconnecting",
            details: "Delay: \(String(format: "%.1f", delay))s"
        )

        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        do {
            try await performConnection()
            ConclaveLogger.shared.logWebSocketEvent("Reconnection successful")
        } catch {
            ConclaveLogger.shared.error(
                "Reconnection failed: \(error.localizedDescription)",
                category: .websocket
            )
            let errorMessage = ErrorMessage(
                message: "Reconnection failed: \(error.localizedDescription)"
            )
            await messageStreamManager.yieldMessage(.error(errorMessage))

            // Try again if we haven't exceeded max attempts
            await attemptReconnection()
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async
    {
        switch message {
        case .string(let text):
            ConclaveLogger.shared.debug(
                "Received WebSocket message: \(text)",
                category: .websocket
            )
            do {
                let data = text.data(using: .utf8)!
                let serverMessage = try decoder.decode(
                    ServerMessage.self,
                    from: data
                )

                // Store in buffer for recent message retrieval
                messageBuffer.append(serverMessage)

                // Yield to stream
                await messageStreamManager.yieldMessage(serverMessage)
            } catch {
                ConclaveLogger.shared.error(
                    "Failed to decode WebSocket message: \(error.localizedDescription) | Message: \(text)",
                    category: .websocket
                )
                let errorMessage = ErrorMessage(
                    message:
                        "Failed to decode message: \(error.localizedDescription)"
                )
                await messageStreamManager.yieldMessage(.error(errorMessage))
            }

        case .data(let data):
            do {
                let serverMessage = try decoder.decode(
                    ServerMessage.self,
                    from: data
                )

                // Store in buffer for recent message retrieval
                messageBuffer.append(serverMessage)

                // Yield to stream
                await messageStreamManager.yieldMessage(serverMessage)
            } catch {
                let errorMessage = ErrorMessage(
                    message:
                        "Failed to decode message: \(error.localizedDescription)"
                )
                await messageStreamManager.yieldMessage(.error(errorMessage))
            }

        @unknown default:
            let errorMessage = ErrorMessage(
                message: "Unknown message type received"
            )
            await messageStreamManager.yieldMessage(.error(errorMessage))
        }
    }
}
