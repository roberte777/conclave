import Foundation

@available(iOS 18.0, *)
public struct ConclaveKit {

    public static func createClient(baseURL: String) throws -> ConclaveClient {
        return try ConclaveAPIClientImpl(baseURLString: baseURL)
    }
}
