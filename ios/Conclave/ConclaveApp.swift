import Clerk
import ConclaveKit
import SwiftUI

@main
struct ConclaveApp: App {
    @State private var clerk = Clerk.shared
    @State private var conclave: ConclaveClientManager? = nil
    @State private var initError: Error? = nil

    var body: some Scene {
        WindowGroup {
            Group {
                if let err = initError {
                    Text("Initialization failed: \(err.localizedDescription)")
                } else if clerk.isLoaded, let conclave {
                    NavigationRootView()
                        .environment(conclave)
                } else {
                    ProgressView()
                }
            }
            .environment(\.clerk, clerk)
            .task {
                if !clerk.isLoaded {
                    clerk.configure(publishableKey: "pk_test_ZmFuY3ktY291Z2FyLTg4LmNsZXJrLmFjY291bnRzLmRldiQ")
                    try? await clerk.load()
                }
            }
            .task(id: clerk.isLoaded) {
                guard clerk.isLoaded, conclave == nil else { return }
                do {
                    AppEnvironment.setupConfiguration()
                    let manager = try ConclaveClientManager(baseURL: AppEnvironment.baseURL)
                    conclave = manager
                } catch {
                    initError = error
                }
            }
        }
    }
}
