import ConclaveKit
import SwiftUI

struct GameSettingsView: View {
    @Environment(ConclaveClientManager.self) private var conclave

    var body: some View {
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
        Text("Room ID: 123")
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
            } catch {
                print("Failed to leave game: \(error)")
            }
        }

    }

    private func leaveGame() {
        guard let currentGame = conclave.currentGame else {
            return
        }
        guard conclave.currentPlayer != nil else {
            return
        }

        Task {
            do {
                try await conclave.leaveGame(
                    gameId: currentGame.id,
                    clerkUserId: conclave.currentPlayer!.clerkUserId
                )

                conclave.clearCurrentGame()
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

    GameSettingsView()
        .environment(mockManager)
}
