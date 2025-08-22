import Foundation

public struct ConclaveConfiguration: Sendable {

    // MARK: - Environment Settings

    public enum Environment: Sendable {
        case development
        case staging
        case production
        case custom(baseURL: String)

        public var baseURL: String {
            switch self {
            case .development:
                return "http://localhost:3001"
            case .staging:
                return "http://localhost:3001"
            case .production:
                return "https://conclave-api.fly.dev"
            case .custom(let baseURL):
                return baseURL
            }
        }

        public var webSocketScheme: String {
            switch self {
            case .development:
                return "ws"
            case .staging, .production:
                return "wss"
            case .custom(let baseURL):
                return baseURL.hasPrefix("https") ? "wss" : "ws"
            }
        }
    }

    // MARK: - Network Configuration

    public struct NetworkConfiguration: Sendable {
        public let requestTimeout: TimeInterval
        public let maxRetryAttempts: Int
        public let retryDelay: TimeInterval

        public static let `default` = NetworkConfiguration(
            requestTimeout: 30.0,
            maxRetryAttempts: 3,
            retryDelay: 1.0
        )

        public static let aggressive = NetworkConfiguration(
            requestTimeout: 10.0,
            maxRetryAttempts: 5,
            retryDelay: 0.5
        )

        public static let relaxed = NetworkConfiguration(
            requestTimeout: 60.0,
            maxRetryAttempts: 2,
            retryDelay: 2.0
        )
    }

    // MARK: - WebSocket Configuration

    public struct WebSocketConfiguration: Sendable {
        public let maxReconnectAttempts: Int
        public let baseReconnectDelay: TimeInterval
        public let maxReconnectDelay: TimeInterval
        public let heartbeatInterval: TimeInterval?
        public let messageQueueSize: Int

        public static let `default` = WebSocketConfiguration(
            maxReconnectAttempts: 5,
            baseReconnectDelay: 1.0,
            maxReconnectDelay: 30.0,
            heartbeatInterval: nil,
            messageQueueSize: 100
        )

        public static let reliable = WebSocketConfiguration(
            maxReconnectAttempts: 10,
            baseReconnectDelay: 0.5,
            maxReconnectDelay: 15.0,
            heartbeatInterval: 30.0,
            messageQueueSize: 200
        )

        public static let minimal = WebSocketConfiguration(
            maxReconnectAttempts: 2,
            baseReconnectDelay: 2.0,
            maxReconnectDelay: 60.0,
            heartbeatInterval: nil,
            messageQueueSize: 50
        )
    }

    // MARK: - Logging Configuration

    public struct LoggingConfiguration: Sendable {
        public let isEnabled: Bool
        public let minimumLevel: ConclaveLogger.LogLevel
        public let logToConsole: Bool
        public let logToOSLog: Bool
        public let logNetworkRequests: Bool
        public let logWebSocketMessages: Bool
        public let logStateChanges: Bool

        public static let `default` = LoggingConfiguration(
            isEnabled: true,
            minimumLevel: {
                #if DEBUG
                    return .debug
                #else
                    return .info
                #endif
            }(),
            logToConsole: true,
            logToOSLog: true,
            logNetworkRequests: true,
            logWebSocketMessages: false,  // Can be verbose
            logStateChanges: true
        )

        public static let verbose = LoggingConfiguration(
            isEnabled: true,
            minimumLevel: .debug,
            logToConsole: true,
            logToOSLog: true,
            logNetworkRequests: true,
            logWebSocketMessages: true,
            logStateChanges: true
        )

        public static let minimal = LoggingConfiguration(
            isEnabled: true,
            minimumLevel: .error,
            logToConsole: false,
            logToOSLog: true,
            logNetworkRequests: false,
            logWebSocketMessages: false,
            logStateChanges: false
        )

        public static let disabled = LoggingConfiguration(
            isEnabled: false,
            minimumLevel: .error,
            logToConsole: false,
            logToOSLog: false,
            logNetworkRequests: false,
            logWebSocketMessages: false,
            logStateChanges: false
        )
    }

    // MARK: - Game Configuration

    public struct GameConfiguration: Sendable {
        public let defaultStartingLife: Int32
        public let maxPlayers: Int
        public let lifeChangeLimit: Int32
        public let recentChangesLimit: Int

        public static let `default` = GameConfiguration(
            defaultStartingLife: 20,
            maxPlayers: 8,
            lifeChangeLimit: 100,
            recentChangesLimit: 10
        )

        public static let commander = GameConfiguration(
            defaultStartingLife: 40,
            maxPlayers: 4,
            lifeChangeLimit: 100,
            recentChangesLimit: 15
        )
    }

    // MARK: - Main Configuration

    public let environment: Environment
    public let network: NetworkConfiguration
    public let webSocket: WebSocketConfiguration
    public let logging: LoggingConfiguration
    public let game: GameConfiguration

    public init(
        environment: Environment,
        network: NetworkConfiguration = .default,
        webSocket: WebSocketConfiguration = .default,
        logging: LoggingConfiguration = .default,
        game: GameConfiguration = .default
    ) {
        self.environment = environment
        self.network = network
        self.webSocket = webSocket
        self.logging = logging
        self.game = game
    }

    // MARK: - Predefined Configurations

    public static let development = ConclaveConfiguration(
        environment: .development,
        network: .default,
        webSocket: .default,
        logging: .verbose,
        game: .default
    )

    public static let staging = ConclaveConfiguration(
        environment: .staging,
        network: .default,
        webSocket: .reliable,
        logging: .default,
        game: .default
    )

    public static let production = ConclaveConfiguration(
        environment: .production,
        network: .relaxed,
        webSocket: .reliable,
        logging: .minimal,
        game: .default
    )

    // MARK: - Computed Properties

    public var baseURL: String {
        return environment.baseURL
    }

    public var apiVersion: String {
        return "v1"
    }

    public var fullAPIURL: String {
        return "\(baseURL)/api/\(apiVersion)"
    }

    public var webSocketURL: String {
        let scheme = environment.webSocketScheme
        let host = baseURL.replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
        return "\(scheme)://\(host)/ws"
    }
}

// MARK: - Configuration Manager

@MainActor
public final class ConclaveConfigurationManager {
    public static let shared = ConclaveConfigurationManager()

    private var _configuration: ConclaveConfiguration

    private init() {
        // Default to development configuration
        self._configuration = .development
    }

    public var configuration: ConclaveConfiguration {
        return _configuration
    }

    public func setConfiguration(_ configuration: ConclaveConfiguration) {
        _configuration = configuration

        // Apply logging configuration
        let logger = ConclaveLogger.shared
        logger.isEnabled = configuration.logging.isEnabled
        logger.minimumLogLevel = configuration.logging.minimumLevel
        logger.logToConsole = configuration.logging.logToConsole
        logger.logToOSLog = configuration.logging.logToOSLog

        logInfo(
            "Configuration updated to \(configuration.environment)",
            category: .general
        )
    }

    // MARK: - Environment Detection

    public func detectEnvironment() -> ConclaveConfiguration.Environment {
        // Try to detect environment from build configuration or environment variables
        #if DEBUG
            return .development
        #else
            // In production, you might want to read from Info.plist or other configuration
            return .production
        #endif
    }

    // MARK: - Configuration from Bundle

    public func loadConfiguration(from bundle: Bundle = .main)
        -> ConclaveConfiguration?
    {
        guard
            let path = bundle.path(
                forResource: "ConclaveConfiguration",
                ofType: "plist"
            ),
            let plist = NSDictionary(contentsOfFile: path)
        else {
            return nil
        }

        // Parse configuration from plist
        // This is a simplified example - you'd want more robust parsing
        if let environmentString = plist["Environment"] as? String {
            let environment: ConclaveConfiguration.Environment
            switch environmentString.lowercased() {
            case "development":
                environment = .development
            case "staging":
                environment = .staging
            case "production":
                environment = .production
            default:
                if let customURL = plist["BaseURL"] as? String {
                    environment = .custom(baseURL: customURL)
                } else {
                    return nil
                }
            }

            return ConclaveConfiguration(environment: environment)
        }

        return nil
    }
}
