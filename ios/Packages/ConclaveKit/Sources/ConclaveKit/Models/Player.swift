import Foundation

public struct Player: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let gameId: UUID
    public let clerkUserId: String
    public let currentLife: Int32
    public let position: Int32
    public let isEliminated: Bool

    public init(
        id: UUID,
        gameId: UUID,
        clerkUserId: String,
        currentLife: Int32,
        position: Int32,
        isEliminated: Bool
    ) {
        self.id = id
        self.gameId = gameId
        self.clerkUserId = clerkUserId
        self.currentLife = currentLife
        self.position = position
        self.isEliminated = isEliminated
    }
}

public struct UserInfo: Codable, Equatable, Sendable {
    public let clerkUserId: String

    public init(clerkUserId: String) {
        self.clerkUserId = clerkUserId
    }
}
