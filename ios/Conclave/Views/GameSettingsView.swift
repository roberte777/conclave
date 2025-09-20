import ConclaveKit
import SwiftUI

struct GameSettingsView: View {
    @Binding var screenPath: NavigationPath
    @Environment(ConclaveClientManager.self) private var conclave
    @Environment(\.clerk) private var clerk

    var body: some View {
        if let currentGame = conclave.currentGame {
            VStack {
                Text("Settings").font(.headline)
                List {
                    Text("Add Guest")
                    Text("Complete Game")
                    Text("Cancel Game")
                        .onTapGesture(
                            perform: cancelGame
                        )
                    Text("Leave Game")
                        .foregroundStyle(.red)
                        .onTapGesture(
                            perform: leaveGame
                        )
                }
            }
            Text(currentGame.name)
        } else {
            Text("No current game exists.")
        }
    }

    private func cancelGame() {
        guard let currentGame = conclave.currentGame else {
            return
        }
        guard conclave.currentPlayer != nil else {
            return
        }

        Task {
            do {
                _ = try await conclave.endGame(
                    gameId: currentGame.id,
                )

                conclave.clearCurrentGame()
                screenPath = NavigationPath()
            } catch {
                print("Failed to leave game: \(error)")
            }
        }

    }

    private func leaveGame() {
        guard let currentGame = conclave.currentGame else {
            return
        }
        guard clerk.user != nil else {
            return
        }

        Task {
            do {
                try await conclave.leaveGame(
                    gameId: currentGame.id,
                    clerkUserId: clerk.user!.id
                )

                conclave.clearCurrentGame()
                screenPath = NavigationPath()
            } catch {
                print("Failed to leave game: \(error)")
            }
        }

    }
}

#Preview {
    @Previewable @State var mockManager: ConclaveClientManager = {
        let manager = ConclaveClientManager(client: MockConclaveClient.testing)

        // Setup mock game state for preview
        let mockGame = Game(
            id: UUID(),
            name: "Preview Game",
            status: .active,
            startingLife: 40,
            createdAt: Date(),
            finishedAt: nil
        )
        let mockPlayer = Player(
            id: UUID(),
            gameId: mockGame.id,
            clerkUserId: "preview_user",
            currentLife: 40,
            position: 1,
            isEliminated: false
        )

        manager.currentGame = mockGame
        manager.currentPlayer = mockPlayer

        return manager
    }()

    GameSettingsView(screenPath: .constant(NavigationPath()))
        .environment(mockManager)
}
