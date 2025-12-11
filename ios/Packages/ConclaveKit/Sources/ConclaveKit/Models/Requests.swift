import Foundation

public struct CreateGameRequest: Codable, Sendable {
    public let startingLife: Int32?

    public init(startingLife: Int32? = nil) {
        self.startingLife = startingLife
    }
}

public struct UpdateLifeRequest: Codable, Sendable {
    public let playerId: UUID
    public let changeAmount: Int32

    public init(playerId: UUID, changeAmount: Int32) {
        self.playerId = playerId
        self.changeAmount = changeAmount
    }
}

public struct UpdateCommanderDamageRequest: Codable, Sendable {
    public let fromPlayerId: UUID
    public let toPlayerId: UUID
    public let commanderNumber: Int32
    public let damageAmount: Int32

    public init(fromPlayerId: UUID, toPlayerId: UUID, commanderNumber: Int32, damageAmount: Int32) {
        self.fromPlayerId = fromPlayerId
        self.toPlayerId = toPlayerId
        self.commanderNumber = commanderNumber
        self.damageAmount = damageAmount
    }
}

public struct TogglePartnerRequest: Codable, Sendable {
    public let playerId: UUID
    public let enablePartner: Bool

    public init(playerId: UUID, enablePartner: Bool) {
        self.playerId = playerId
        self.enablePartner = enablePartner
    }
}

public struct EndGameRequest: Codable, Sendable {
    public let winnerPlayerId: UUID?

    public init(winnerPlayerId: UUID? = nil) {
        self.winnerPlayerId = winnerPlayerId
    }
}
