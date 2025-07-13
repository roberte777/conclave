import Foundation
import os.log

public final class ConclaveLogger: @unchecked Sendable {

    public enum LogLevel: Int, CaseIterable, Sendable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3

        var osLogType: OSLogType {
            switch self {
            case .debug:
                return .debug
            case .info:
                return .info
            case .warning:
                return .default
            case .error:
                return .error
            }
        }

        var emoji: String {
            switch self {
            case .debug:
                return "🔍"
            case .info:
                return "ℹ️"
            case .warning:
                return "⚠️"
            case .error:
                return "❌"
            }
        }
    }

    public enum Category: String, CaseIterable, Sendable {
        case network = "Network"
        case websocket = "WebSocket"
        case state = "State"
        case error = "Error"
        case general = "General"

        var osLog: OSLog {
            return OSLog(
                subsystem: "com.conclave.ConclaveKit",
                category: self.rawValue
            )
        }
    }

    public static let shared = ConclaveLogger()

    private let dateFormatter: DateFormatter
    private let queue = DispatchQueue(
        label: "com.conclave.logger",
        qos: .utility
    )

    // Configuration
    public var minimumLogLevel: LogLevel = {
        #if DEBUG
            return .debug
        #else
            return .info
        #endif
    }()

    public var isEnabled = true
    public var logToConsole = true
    public var logToOSLog = true

    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }

    // MARK: - Public Logging Methods

    public func debug(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            level: .debug,
            message: message,
            category: category,
            file: file,
            function: function,
            line: line
        )
    }

    public func info(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            level: .info,
            message: message,
            category: category,
            file: file,
            function: function,
            line: line
        )
    }

    public func warning(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            level: .warning,
            message: message,
            category: category,
            file: file,
            function: function,
            line: line
        )
    }

    public func error(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            level: .error,
            message: message,
            category: category,
            file: file,
            function: function,
            line: line
        )
    }

    public func error(
        _ error: Error,
        context: String? = nil,
        category: Category = .error,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let message =
            if let context = context {
                "\(context): \(error.localizedDescription)"
            } else {
                error.localizedDescription
            }
        log(
            level: .error,
            message: message,
            category: category,
            file: file,
            function: function,
            line: line
        )
    }

    // MARK: - Network Logging Helpers

    public func logHTTPRequest(
        method: String,
        url: String,
        headers: [String: String]? = nil
    ) {
        var message = "🌐 HTTP \(method) \(url)"
        if let headers = headers, !headers.isEmpty {
            message += " | Headers: \(headers)"
        }
        log(level: .debug, message: message, category: .network)
    }

    public func logHTTPResponse(
        statusCode: Int,
        url: String,
        responseTime: TimeInterval? = nil
    ) {
        var message = "🌐 HTTP Response \(statusCode) \(url)"
        if let responseTime = responseTime {
            message += " | Time: \(String(format: "%.3f", responseTime))s"
        }
        log(
            level: statusCode >= 400 ? .error : .debug,
            message: message,
            category: .network
        )
    }

    public func logWebSocketEvent(
        _ event: String,
        gameId: UUID? = nil,
        details: String? = nil
    ) {
        var message = "🔌 WebSocket \(event)"
        if let gameId = gameId {
            message += " | Game: \(gameId.uuidString.prefix(8))"
        }
        if let details = details {
            message += " | \(details)"
        }
        log(level: .info, message: message, category: .websocket)
    }

    // MARK: - State Logging Helpers

    public func logStateChange(_ change: String, details: String? = nil) {
        var message = "📊 State: \(change)"
        if let details = details {
            message += " | \(details)"
        }
        log(level: .debug, message: message, category: .state)
    }

    // MARK: - Private Implementation

    private func log(
        level: LogLevel,
        message: String,
        category: Category,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled && level.rawValue >= minimumLogLevel.rawValue else {
            return
        }

        queue.async { [weak self] in
            guard let self = self else { return }

            let filename = URL(fileURLWithPath: file).lastPathComponent
            let timestamp = self.dateFormatter.string(from: Date())

            let logMessage =
                "[\(timestamp)] \(level.emoji) [\(category.rawValue)] \(message) | \(filename):\(line) \(function)"

            if self.logToConsole {
                print(logMessage)
            }

            if self.logToOSLog {
                os_log(
                    "%{public}@",
                    log: category.osLog,
                    type: level.osLogType,
                    logMessage
                )
            }
        }
    }
}

// MARK: - Global Convenience Functions

public func logDebug(
    _ message: String,
    category: ConclaveLogger.Category = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    ConclaveLogger.shared.debug(
        message,
        category: category,
        file: file,
        function: function,
        line: line
    )
}

public func logInfo(
    _ message: String,
    category: ConclaveLogger.Category = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    ConclaveLogger.shared.info(
        message,
        category: category,
        file: file,
        function: function,
        line: line
    )
}

public func logWarning(
    _ message: String,
    category: ConclaveLogger.Category = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    ConclaveLogger.shared.warning(
        message,
        category: category,
        file: file,
        function: function,
        line: line
    )
}

public func logError(
    _ message: String,
    category: ConclaveLogger.Category = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    ConclaveLogger.shared.error(
        message,
        category: category,
        file: file,
        function: function,
        line: line
    )
}

public func logError(
    _ error: Error,
    context: String? = nil,
    category: ConclaveLogger.Category = .error,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    ConclaveLogger.shared.error(
        error,
        context: context,
        category: category,
        file: file,
        function: function,
        line: line
    )
}
