import Foundation

public struct LifeChange: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let gameId: UUID
    public let playerId: UUID
    public let changeAmount: Int32
    public let newLifeTotal: Int32
    public let createdAt: Date

    public init(
        id: UUID,
        gameId: UUID,
        playerId: UUID,
        changeAmount: Int32,
        newLifeTotal: Int32,
        createdAt: Date
    ) {
        self.id = id
        self.gameId = gameId
        self.playerId = playerId
        self.changeAmount = changeAmount
        self.newLifeTotal = newLifeTotal
        self.createdAt = createdAt
    }
}
