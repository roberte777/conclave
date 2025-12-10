import Foundation

public struct Game: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let status: GameStatus
    public let startingLife: Int32
    public let winnerPlayerId: UUID?
    public let createdAt: Date
    public let finishedAt: Date?

    public init(
        id: UUID,
        name: String,
        status: GameStatus,
        startingLife: Int32,
        winnerPlayerId: UUID? = nil,
        createdAt: Date,
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.startingLife = startingLife
        self.winnerPlayerId = winnerPlayerId
        self.createdAt = createdAt
        self.finishedAt = finishedAt
    }
}

public enum GameStatus: String, Codable, CaseIterable, Sendable {
    case active = "active"
    case finished = "finished"
}
