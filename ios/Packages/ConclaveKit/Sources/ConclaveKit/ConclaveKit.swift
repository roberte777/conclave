import Foundation

/// ConclaveKit - Swift SDK for Conclave Magic: The Gathering Life Tracking API
///
/// Provides HTTP and WebSocket clients for real-time multiplayer MTG life tracking.
/// Supports automatic reconnection, state management, and comprehensive error handling.
@available(iOS 18.0, *)
public struct ConclaveKit {

    // MARK: - Client Creation

    /// Creates a client with a custom base URL
    /// - Parameter baseURL: The base URL for the Conclave API
    /// - Returns: A configured ConclaveClient
    /// - Throws: ConclaveError.invalidURL if the URL is malformed
    public static func createClient(baseURL: String) throws -> ConclaveClient {
        return try ConclaveAPIClientImpl(baseURLString: baseURL)
    }

    public static func createClient(configuration: ConclaveConfiguration) throws
        -> ConclaveClient
    {
        // Apply the configuration globally
        Task { @MainActor in
            ConclaveConfigurationManager.shared.setConfiguration(configuration)
        }

        // Create client with the configured base URL
        return try ConclaveAPIClientImpl(baseURLString: configuration.baseURL)
    }

    public static func createClient(
        environment: ConclaveConfiguration.Environment
    ) throws -> ConclaveClient {
        let configuration = ConclaveConfiguration(environment: environment)
        return try createClient(configuration: configuration)
    }

    // MARK: - Configuration Management

    @MainActor
    public static var configuration: ConclaveConfiguration {
        return ConclaveConfigurationManager.shared.configuration
    }

    @MainActor
    public static func setConfiguration(_ configuration: ConclaveConfiguration)
    {
        ConclaveConfigurationManager.shared.setConfiguration(configuration)
    }

    // MARK: - Predefined Clients

    public static func createDevelopmentClient() throws -> ConclaveClient {
        return try createClient(configuration: .development)
    }

    public static func createStagingClient() throws -> ConclaveClient {
        return try createClient(configuration: .staging)
    }

    public static func createProductionClient() throws -> ConclaveClient {
        return try createClient(configuration: .production)
    }
}
