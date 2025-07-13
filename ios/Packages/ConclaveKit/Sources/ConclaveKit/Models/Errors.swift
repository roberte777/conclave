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
    case gameNotFound(String)
    case playerNotFound(String)
    case gameNotActive(String)
    case authenticationFailed(String)
    case serverError(String)
    case unknown(String)

    // MARK: - Recovery Information

    public var isRecoverable: Bool {
        switch self {
        case .networkError:
            return true
        case .httpError(let statusCode, _):
            return statusCode >= 500 || statusCode == 429  // Server errors and rate limits
        case .notConnected, .connectionFailed:
            return true
        case .timeout:
            return true
        case .decodingError, .encodingError, .invalidURL:
            return false  // Programming errors
        case .gameNotFound, .playerNotFound, .gameNotActive,
            .authenticationFailed:
            return false  // Business logic errors
        case .webSocketError, .serverError:
            return true
        case .unknown:
            return true
        }
    }

    public var retryDelay: TimeInterval? {
        switch self {
        case .networkError:
            return 2.0
        case .httpError(let statusCode, _):
            return statusCode == 429 ? 5.0 : (statusCode >= 500 ? 3.0 : nil)
        case .notConnected, .connectionFailed:
            return 1.0
        case .timeout:
            return 1.5
        case .webSocketError, .serverError:
            return 2.0
        default:
            return nil
        }
    }

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
        case .gameNotFound(let message):
            return "Game not found: \(message)"
        case .playerNotFound(let message):
            return "Player not found: \(message)"
        case .gameNotActive(let message):
            return "Game not active: \(message)"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
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
