import Foundation

public struct CreateGameRequest: Codable, Sendable {
    public let name: String
    public let startingLife: Int32?
    public let clerkUserId: String

    public init(name: String, startingLife: Int32? = nil, clerkUserId: String) {
        self.name = name
        self.startingLife = startingLife
        self.clerkUserId = clerkUserId
    }
}

public struct JoinGameRequest: Codable, Sendable {
    public let clerkUserId: String

    public init(clerkUserId: String) {
        self.clerkUserId = clerkUserId
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
