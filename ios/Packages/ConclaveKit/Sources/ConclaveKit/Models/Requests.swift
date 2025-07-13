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
