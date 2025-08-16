import ConclaveKit
import Foundation

enum AppEnvironment {
    @MainActor
    static var baseURL: String {
        return ConclaveKit.configuration.fullAPIURL
    }

    @MainActor
    static func setupConfiguration() {
        ConclaveKit.setConfiguration(.production)
    }
}
