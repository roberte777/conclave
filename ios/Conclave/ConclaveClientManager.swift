import ConclaveKit
import SwiftUI

@available(iOS 17.0, *)
@Observable @MainActor
public class ConclaveClientManager {

    // MARK: - Private Properties
    private let client: ConclaveAPIClient

    // MARK: - Public Reactive State
    public var isLoading = false
    public var lastError: ConclaveError?
    public var currentGame: Game?
    public var currentPlayer: Player?

    // MARK: - Initialization
    public init(client: ConclaveAPIClient) {
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

    // MARK: - Utility Methods

    public func clearCurrentGame() {
        currentGame = nil
        currentPlayer = nil
    }

    public func clearError() {
        lastError = nil
    }

    // MARK: - Direct Client Access
    public var underlyingClient: ConclaveAPIClient {
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
