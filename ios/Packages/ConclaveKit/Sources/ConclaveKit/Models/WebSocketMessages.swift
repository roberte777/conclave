import Foundation

public enum WebSocketMessage {
    public enum ClientAction: String, CaseIterable {
        case updateLife = "updateLife"
        case joinGame = "joinGame"
        case leaveGame = "leaveGame"
        case getGameState = "getGameState"
        case endGame = "endGame"
        case setCommanderDamage = "setCommanderDamage"
        case updateCommanderDamage = "updateCommanderDamage"
        case togglePartner = "togglePartner"
    }

    public enum ServerMessageType: String, CaseIterable {
        case lifeUpdate = "lifeUpdate"
        case playerJoined = "playerJoined"
        case playerLeft = "playerLeft"
        case gameStarted = "gameStarted"
        case gameEnded = "gameEnded"
        case commanderDamageUpdate = "commanderDamageUpdate"
        case partnerToggled = "partnerToggled"
        case error = "error"
    }
}

public enum ClientMessage: Codable, Sendable {
    case updateLife(playerId: UUID, changeAmount: Int32)
    case joinGame(clerkUserId: String)
    case leaveGame(playerId: UUID)
    case getGameState
    case endGame
    case setCommanderDamage(fromPlayerId: UUID, toPlayerId: UUID, commanderNumber: Int32, newDamage: Int32)
    case updateCommanderDamage(fromPlayerId: UUID, toPlayerId: UUID, commanderNumber: Int32, damageAmount: Int32)
    case togglePartner(playerId: UUID, enablePartner: Bool)

    private enum CodingKeys: String, CodingKey {
        case action
        case playerId
        case changeAmount
        case clerkUserId
        case fromPlayerId
        case toPlayerId
        case commanderNumber
        case newDamage
        case damageAmount
        case enablePartner
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let action = try container.decode(String.self, forKey: .action)

        switch action {
        case "updateLife":
            let playerId = try container.decode(UUID.self, forKey: .playerId)
            let changeAmount = try container.decode(
                Int32.self,
                forKey: .changeAmount
            )
            self = .updateLife(playerId: playerId, changeAmount: changeAmount)
        case "joinGame":
            let clerkUserId = try container.decode(
                String.self,
                forKey: .clerkUserId
            )
            self = .joinGame(clerkUserId: clerkUserId)
        case "leaveGame":
            let playerId = try container.decode(UUID.self, forKey: .playerId)
            self = .leaveGame(playerId: playerId)
        case "getGameState":
            self = .getGameState
        case "endGame":
            self = .endGame
        case "setCommanderDamage":
            let fromPlayerId = try container.decode(UUID.self, forKey: .fromPlayerId)
            let toPlayerId = try container.decode(UUID.self, forKey: .toPlayerId)
            let commanderNumber = try container.decode(Int32.self, forKey: .commanderNumber)
            let newDamage = try container.decode(Int32.self, forKey: .newDamage)
            self = .setCommanderDamage(fromPlayerId: fromPlayerId, toPlayerId: toPlayerId, commanderNumber: commanderNumber, newDamage: newDamage)
        case "updateCommanderDamage":
            let fromPlayerId = try container.decode(UUID.self, forKey: .fromPlayerId)
            let toPlayerId = try container.decode(UUID.self, forKey: .toPlayerId)
            let commanderNumber = try container.decode(Int32.self, forKey: .commanderNumber)
            let damageAmount = try container.decode(Int32.self, forKey: .damageAmount)
            self = .updateCommanderDamage(fromPlayerId: fromPlayerId, toPlayerId: toPlayerId, commanderNumber: commanderNumber, damageAmount: damageAmount)
        case "togglePartner":
            let playerId = try container.decode(UUID.self, forKey: .playerId)
            let enablePartner = try container.decode(Bool.self, forKey: .enablePartner)
            self = .togglePartner(playerId: playerId, enablePartner: enablePartner)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown action: \(action)"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .updateLife(let playerId, let changeAmount):
            try container.encode("updateLife", forKey: .action)
            try container.encode(playerId, forKey: .playerId)
            try container.encode(changeAmount, forKey: .changeAmount)
        case .joinGame(let clerkUserId):
            try container.encode("joinGame", forKey: .action)
            try container.encode(clerkUserId, forKey: .clerkUserId)
        case .leaveGame(let playerId):
            try container.encode("leaveGame", forKey: .action)
            try container.encode(playerId, forKey: .playerId)
        case .getGameState:
            try container.encode("getGameState", forKey: .action)
        case .endGame:
            try container.encode("endGame", forKey: .action)
        case .setCommanderDamage(let fromPlayerId, let toPlayerId, let commanderNumber, let newDamage):
            try container.encode("setCommanderDamage", forKey: .action)
            try container.encode(fromPlayerId, forKey: .fromPlayerId)
            try container.encode(toPlayerId, forKey: .toPlayerId)
            try container.encode(commanderNumber, forKey: .commanderNumber)
            try container.encode(newDamage, forKey: .newDamage)
        case .updateCommanderDamage(let fromPlayerId, let toPlayerId, let commanderNumber, let damageAmount):
            try container.encode("updateCommanderDamage", forKey: .action)
            try container.encode(fromPlayerId, forKey: .fromPlayerId)
            try container.encode(toPlayerId, forKey: .toPlayerId)
            try container.encode(commanderNumber, forKey: .commanderNumber)
            try container.encode(damageAmount, forKey: .damageAmount)
        case .togglePartner(let playerId, let enablePartner):
            try container.encode("togglePartner", forKey: .action)
            try container.encode(playerId, forKey: .playerId)
            try container.encode(enablePartner, forKey: .enablePartner)
        }
    }
}

public enum ServerMessage: Codable, Sendable {
    case lifeUpdate(LifeUpdateMessage)
    case playerJoined(PlayerJoinedMessage)
    case playerLeft(PlayerLeftMessage)
    case gameStarted(GameStartedMessage)
    case gameEnded(GameEndedMessage)
    case commanderDamageUpdate(CommanderDamageUpdateMessage)
    case partnerToggled(PartnerToggledMessage)
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
        case "commanderDamageUpdate":
            self = .commanderDamageUpdate(try CommanderDamageUpdateMessage(from: decoder))
        case "partnerToggled":
            self = .partnerToggled(try PartnerToggledMessage(from: decoder))
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
        case .commanderDamageUpdate(let message):
            try message.encode(to: encoder)
        case .partnerToggled(let message):
            try message.encode(to: encoder)
        case .error(let message):
            try message.encode(to: encoder)
        }
    }
}

public struct LifeUpdateMessage: Codable, Sendable {
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

public struct PlayerJoinedMessage: Codable, Sendable {
    public let type: String
    public let gameId: UUID
    public let player: Player

    public init(gameId: UUID, player: Player) {
        self.type = "playerJoined"
        self.gameId = gameId
        self.player = player
    }
}

public struct PlayerLeftMessage: Codable, Sendable {
    public let type: String
    public let gameId: UUID
    public let playerId: UUID

    public init(gameId: UUID, playerId: UUID) {
        self.type = "playerLeft"
        self.gameId = gameId
        self.playerId = playerId
    }
}

public struct GameStartedMessage: Codable, Sendable {
    public let type: String
    public let gameId: UUID
    public let players: [Player]
    public let commanderDamage: [CommanderDamage]?

    public init(gameId: UUID, players: [Player], commanderDamage: [CommanderDamage]? = nil) {
        self.type = "gameStarted"
        self.gameId = gameId
        self.players = players
        self.commanderDamage = commanderDamage
    }
}

public struct GameEndedMessage: Codable, Sendable {
    public let type: String
    public let gameId: UUID
    public let winner: Player?

    public init(gameId: UUID, winner: Player? = nil) {
        self.type = "gameEnded"
        self.gameId = gameId
        self.winner = winner
    }
}

public struct ErrorMessage: Codable, Sendable {
    public let type: String
    public let message: String

    public init(message: String) {
        self.type = "error"
        self.message = message
    }
}

public struct CommanderDamageUpdateMessage: Codable, Sendable {
    public let type: String
    public let gameId: UUID
    public let fromPlayerId: UUID
    public let toPlayerId: UUID
    public let commanderNumber: Int32
    public let newDamage: Int32
    public let damageAmount: Int32

    public init(
        gameId: UUID,
        fromPlayerId: UUID,
        toPlayerId: UUID,
        commanderNumber: Int32,
        newDamage: Int32,
        damageAmount: Int32
    ) {
        self.type = "commanderDamageUpdate"
        self.gameId = gameId
        self.fromPlayerId = fromPlayerId
        self.toPlayerId = toPlayerId
        self.commanderNumber = commanderNumber
        self.newDamage = newDamage
        self.damageAmount = damageAmount
    }
}

public struct PartnerToggledMessage: Codable, Sendable {
    public let type: String
    public let gameId: UUID
    public let playerId: UUID
    public let hasPartner: Bool

    public init(gameId: UUID, playerId: UUID, hasPartner: Bool) {
        self.type = "partnerToggled"
        self.gameId = gameId
        self.playerId = playerId
        self.hasPartner = hasPartner
    }
}
