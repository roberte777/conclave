import Foundation

public struct HealthResponse: Codable, Equatable, Sendable {
    public let status: String
    public let service: String

    public init(status: String, service: String) {
        self.status = status
        self.service = service
    }
}

public struct StatsResponse: Codable, Equatable, Sendable {
    public let activeGames: Int
    public let service: String

    public init(activeGames: Int, service: String) {
        self.activeGames = activeGames
        self.service = service
    }
}
