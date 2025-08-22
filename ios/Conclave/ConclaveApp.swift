import ConclaveKit
import SwiftUI

@main
struct ConclaveApp: App {
    let conclave: ConclaveClientManager

    init() {
        do {
            AppEnvironment.setupConfiguration()
            conclave = try ConclaveClientManager(
                baseURL: AppEnvironment.baseURL
            )
        } catch {
            fatalError("Could not initialize ConclaveClientManager: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            NavigationRootView()
                .environment(conclave)
        }
    }
}
