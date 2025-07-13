import Foundation

public enum ConclaveError: Error, LocalizedError, Equatable, Sendable {
    case networkError(URLError)
    case httpError(statusCode: Int, message: String?)
    case decodingError(String)
    case encodingError(String)
    case invalidURL(String)
    case webSocketError(String)
    case notConnected
    case connectionFailed(String)
    case timeout
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .networkError(let urlError):
            return "Network error: \(urlError.localizedDescription)"
        case .httpError(let statusCode, let message):
            return "HTTP error \(statusCode): \(message ?? "Unknown error")"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .encodingError(let message):
            return "Failed to encode request: \(message)"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .webSocketError(let message):
            return "WebSocket error: \(message)"
        case .notConnected:
            return "WebSocket is not connected"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .timeout:
            return "Request timed out"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

public struct APIErrorResponse: Codable, Sendable {
    public let error: String
    public let message: String?

    public init(error: String, message: String? = nil) {
        self.error = error
        self.message = message
    }
}
