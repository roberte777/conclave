import Foundation

public struct GameState: Codable, Equatable, Sendable {
    public let game: Game
    public let players: [Player]
    public let recentChanges: [LifeChange]
    public let commanderDamage: [CommanderDamage]

    public init(game: Game, players: [Player], recentChanges: [LifeChange], commanderDamage: [CommanderDamage] = []) {
        self.game = game
        self.players = players
        self.recentChanges = recentChanges
        self.commanderDamage = commanderDamage
    }
}

public struct GameHistory: Codable, Equatable, Sendable {
    public let games: [GameWithPlayers]

    public init(games: [GameWithPlayers]) {
        self.games = games
    }
}

public struct GameWithPlayers: Codable, Equatable, Sendable {
    public let game: Game
    public let players: [Player]
    public let winner: Player?

    public init(game: Game, players: [Player], winner: Player? = nil) {
        self.game = game
        self.players = players
        self.winner = winner
    }
}

public struct GameWithUsers: Codable, Equatable, Sendable {
    public let game: Game
    public let users: [UserInfo]

    public init(game: Game, users: [UserInfo]) {
        self.game = game
        self.users = users
    }
}
