import Foundation

public enum WebSocketMessage {
    public enum ClientAction: String, CaseIterable {
        case updateLife = "updateLife"
        case joinGame = "joinGame"
        case leaveGame = "leaveGame"
        case getGameState = "getGameState"
        case endGame = "endGame"
    }

    public enum ServerMessageType: String, CaseIterable {
        case lifeUpdate = "lifeUpdate"
        case playerJoined = "playerJoined"
        case playerLeft = "playerLeft"
        case gameStarted = "gameStarted"
        case gameEnded = "gameEnded"
        case error = "error"
    }
}

public struct ClientMessage: Codable {
    public let action: String
    public let playerId: UUID?
    public let changeAmount: Int32?
    public let clerkUserId: String?

    public init(
        action: WebSocketMessage.ClientAction,
        playerId: UUID? = nil,
        changeAmount: Int32? = nil,
        clerkUserId: String? = nil
    ) {
        self.action = action.rawValue
        self.playerId = playerId
        self.changeAmount = changeAmount
        self.clerkUserId = clerkUserId
    }
}

public enum ServerMessage: Codable {
    case lifeUpdate(LifeUpdateMessage)
    case playerJoined(PlayerJoinedMessage)
    case playerLeft(PlayerLeftMessage)
    case gameStarted(GameStartedMessage)
    case gameEnded(GameEndedMessage)
    case error(ErrorMessage)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "lifeUpdate":
            self = .lifeUpdate(try LifeUpdateMessage(from: decoder))
        case "playerJoined":
            self = .playerJoined(try PlayerJoinedMessage(from: decoder))
        case "playerLeft":
            self = .playerLeft(try PlayerLeftMessage(from: decoder))
        case "gameStarted":
            self = .gameStarted(try GameStartedMessage(from: decoder))
        case "gameEnded":
            self = .gameEnded(try GameEndedMessage(from: decoder))
        case "error":
            self = .error(try ErrorMessage(from: decoder))
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown message type: \(type)"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .lifeUpdate(let message):
            try message.encode(to: encoder)
        case .playerJoined(let message):
            try message.encode(to: encoder)
        case .playerLeft(let message):
            try message.encode(to: encoder)
        case .gameStarted(let message):
            try message.encode(to: encoder)
        case .gameEnded(let message):
            try message.encode(to: encoder)
        case .error(let message):
            try message.encode(to: encoder)
        }
    }
}

public struct LifeUpdateMessage: Codable {
    public let type: String
    public let gameId: UUID
    public let playerId: UUID
    public let newLife: Int32
    public let changeAmount: Int32

    public init(
        gameId: UUID,
        playerId: UUID,
        newLife: Int32,
        changeAmount: Int32
    ) {
        self.type = "lifeUpdate"
        self.gameId = gameId
        self.playerId = playerId
        self.newLife = newLife
        self.changeAmount = changeAmount
    }
}

public struct PlayerJoinedMessage: Codable {
    public let type: String
    public let gameId: UUID
    public let player: Player

    public init(gameId: UUID, player: Player) {
        self.type = "playerJoined"
        self.gameId = gameId
        self.player = player
    }
}

public struct PlayerLeftMessage: Codable {
    public let type: String
    public let gameId: UUID
    public let playerId: UUID

    public init(gameId: UUID, playerId: UUID) {
        self.type = "playerLeft"
        self.gameId = gameId
        self.playerId = playerId
    }
}

public struct GameStartedMessage: Codable {
    public let type: String
    public let gameId: UUID
    public let players: [Player]

    public init(gameId: UUID, players: [Player]) {
        self.type = "gameStarted"
        self.gameId = gameId
        self.players = players
    }
}

public struct GameEndedMessage: Codable {
    public let type: String
    public let gameId: UUID
    public let winner: Player?

    public init(gameId: UUID, winner: Player? = nil) {
        self.type = "gameEnded"
        self.gameId = gameId
        self.winner = winner
    }
}

public struct ErrorMessage: Codable {
    public let type: String
    public let message: String

    public init(message: String) {
        self.type = "error"
        self.message = message
    }
}
