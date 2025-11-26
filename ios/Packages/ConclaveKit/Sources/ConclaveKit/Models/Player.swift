import Foundation

public struct Player: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let gameId: UUID
    public let clerkUserId: String
    public let currentLife: Int32
    public let position: Int32
    public let isEliminated: Bool
    public let displayName: String
    public let username: String?
    public let imageUrl: String?

    public init(
        id: UUID,
        gameId: UUID,
        clerkUserId: String,
        currentLife: Int32,
        position: Int32,
        isEliminated: Bool,
        displayName: String = "Unknown",
        username: String? = nil,
        imageUrl: String? = nil
    ) {
        self.id = id
        self.gameId = gameId
        self.clerkUserId = clerkUserId
        self.currentLife = currentLife
        self.position = position
        self.isEliminated = isEliminated
        self.displayName = displayName
        self.username = username
        self.imageUrl = imageUrl
    }
}

public struct UserInfo: Codable, Equatable, Sendable {
    public let clerkUserId: String
    public let displayName: String?
    public let username: String?
    public let imageUrl: String?

    public init(
        clerkUserId: String,
        displayName: String? = nil,
        username: String? = nil,
        imageUrl: String? = nil
    ) {
        self.clerkUserId = clerkUserId
        self.displayName = displayName
        self.username = username
        self.imageUrl = imageUrl
    }
}
