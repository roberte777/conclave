import Foundation

@available(iOS 18.0, *)
public final class WebSocketClient: ConclaveWebSocketClient, @unchecked Sendable
{

    private let baseURL: URL
    private nonisolated(unsafe) var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private let messageStreamContinuation:
        AsyncStream<ServerMessage>.Continuation
    private let _messageStream: AsyncStream<ServerMessage>

    private actor ConnectionState {
        private var _isConnected = false

        func setConnected(_ connected: Bool) {
            _isConnected = connected
        }

        func isConnected() -> Bool {
            return _isConnected
        }
    }

    private let connectionState = ConnectionState()

    public var isConnected: Bool {
        get async {
            await connectionState.isConnected()
        }
    }

    public var messageStream: AsyncStream<ServerMessage> {
        get async {
            return _messageStream
        }
    }

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601

        (self._messageStream, self.messageStreamContinuation) =
            AsyncStream.makeStream(of: ServerMessage.self)
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

    public func connect(gameId: UUID, clerkUserId: String) async throws {
        guard !(await connectionState.isConnected()) else { return }

        var components = URLComponents(
            url: baseURL,
            resolvingAgainstBaseURL: false
        )
        components?.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        components?.path = "/ws"
        components?.queryItems = [
            URLQueryItem(name: "game_id", value: gameId.uuidString),
            URLQueryItem(name: "clerk_user_id", value: clerkUserId),
        ]

        guard let wsURL = components?.url else {
            throw ConclaveError.invalidURL("Failed to construct WebSocket URL")
        }

        webSocketTask = session.webSocketTask(with: wsURL)
        webSocketTask?.resume()

        await connectionState.setConnected(true)

        Task {
            await startListening()
        }
    }

    public func disconnect() async {
        await connectionState.setConnected(false)

        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        messageStreamContinuation.finish()
    }

    // MARK: - Message Sending

    public func sendMessage(_ message: ClientMessage) async throws {
        guard await connectionState.isConnected(),
            let webSocketTask = webSocketTask
        else {
            throw ConclaveError.notConnected
        }

        do {
            let data = try encoder.encode(message)
            let string = String(data: data, encoding: .utf8)!
            try await webSocketTask.send(.string(string))
        } catch {
            throw ConclaveError.encodingError(error.localizedDescription)
        }
    }

    public func updateLife(playerId: UUID, changeAmount: Int32) async throws {
        let message = ClientMessage(
            action: .updateLife,
            playerId: playerId,
            changeAmount: changeAmount
        )
        try await sendMessage(message)
    }

    public func joinGame(clerkUserId: String) async throws {
        let message = ClientMessage(
            action: .joinGame,
            clerkUserId: clerkUserId
        )
        try await sendMessage(message)
    }

    public func leaveGame(playerId: UUID) async throws {
        let message = ClientMessage(
            action: .leaveGame,
            playerId: playerId
        )
        try await sendMessage(message)
    }

    public func getGameState() async throws {
        let message = ClientMessage(action: .getGameState)
        try await sendMessage(message)
    }

    public func endGame() async throws {
        let message = ClientMessage(action: .endGame)
        try await sendMessage(message)
    }

    // MARK: - Private Methods

    private func startListening() async {
        guard let webSocketTask = webSocketTask else { return }

        do {
            while await connectionState.isConnected() {
                let message = try await webSocketTask.receive()
                await handleMessage(message)
            }
        } catch {
            await connectionState.setConnected(false)

            let errorMessage = ErrorMessage(message: error.localizedDescription)
            messageStreamContinuation.yield(.error(errorMessage))
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async
    {
        switch message {
        case .string(let text):
            do {
                let data = text.data(using: .utf8)!
                let serverMessage = try decoder.decode(
                    ServerMessage.self,
                    from: data
                )
                messageStreamContinuation.yield(serverMessage)
            } catch {
                let errorMessage = ErrorMessage(
                    message:
                        "Failed to decode message: \(error.localizedDescription)"
                )
                messageStreamContinuation.yield(.error(errorMessage))
            }

        case .data(let data):
            do {
                let serverMessage = try decoder.decode(
                    ServerMessage.self,
                    from: data
                )
                messageStreamContinuation.yield(serverMessage)
            } catch {
                let errorMessage = ErrorMessage(
                    message:
                        "Failed to decode message: \(error.localizedDescription)"
                )
                messageStreamContinuation.yield(.error(errorMessage))
            }

        @unknown default:
            let errorMessage = ErrorMessage(
                message: "Unknown message type received"
            )
            messageStreamContinuation.yield(.error(errorMessage))
        }
    }
}
