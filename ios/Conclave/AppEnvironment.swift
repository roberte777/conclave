import Foundation

enum AppEnvironment {
    static var baseURL: String {
        #if DEBUG
            return "http://localhost:3001/api/v1"
        #else
            return "http://localhost:3001/api/v1"
        #endif
    }
}
