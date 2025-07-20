import Foundation

public struct CommanderDamage: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let gameId: UUID
    public let fromPlayerId: UUID
    public let toPlayerId: UUID
    public let commanderNumber: Int32
    public let damage: Int32
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        gameId: UUID,
        fromPlayerId: UUID,
        toPlayerId: UUID,
        commanderNumber: Int32,
        damage: Int32,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.gameId = gameId
        self.fromPlayerId = fromPlayerId
        self.toPlayerId = toPlayerId
        self.commanderNumber = commanderNumber
        self.damage = damage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}