import SwiftUI

struct NavigationRootView: View {
    @State private var screenPath = NavigationPath()
    @Environment(ConclaveClientManager.self) private var conclave

    var body: some View {
        NavigationStack(path: $screenPath) {
            HomeScreenView(screenPath: $screenPath)
                .navigationDestination(for: Screen.self) { screen in
                    switch screen {
                    case .offlineGame:
                        FourPlayerGameView(screenPath: $screenPath)
                            .navigationBarBackButtonHidden()
                    case .userSettings:
                        UserSettingsView()
                    }
                }
        }
    }
}
