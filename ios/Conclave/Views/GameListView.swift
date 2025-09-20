import Clerk
import ConclaveKit
import SwiftUI

struct GameListView: View {
    @Binding var screenPath: NavigationPath
    @Environment(ConclaveClientManager.self) private var conclave
    @Environment(\.clerk) private var clerk
    @State private var showCreateAlert = false
    @State private var newGameName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: {
                    showCreateAlert = true
                }) {
                    Text("Create Game")
                }
                .alert(
                    "New Game",
                    isPresented: $showCreateAlert,
                    actions: {
                        TextField("Game Name", text: $newGameName)
                        Button("Create") {
                            if let user = clerk.user {
                                Task {
                                    await addGame(
                                        gameName: newGameName,
                                        clerkUserId: user.id
                                    )
                                    newGameName = ""
                                }
                            } else {
                                // Not logged in, show error
                                print(
                                    "You must be logged in to create a game."
                                )
                            }
                        }
                        Button("Cancel", role: .cancel) {
                            newGameName = ""
                        }
                    },
                    message: {
                        Text("Enter info for your new game")
                    }
                )
                Spacer()
                Button(action: {
                    Task {
                        await getAllGames()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.primary)
                        .fontWeight(.bold)
                        .padding(10)
                        .background(Circle().fill(.background))
                }

            }.task {
                await getAllGames()
            }
            .padding(.bottom, 16)

            Text("Game List")
                .font(.title)
                .bold()
            ForEach(conclave.allGames) { item in
                Button(action: {
                    if let user = clerk.user {
                        Task {
                            await joinGame(
                                gameId: item.game.id,
                                clerkUserId: user.id
                            )
                        }
                    } else {
                        print(
                            "You must be logged in to join a game."
                        )
                    }
                }) {
                    Text(item.game.name)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }

        }
        .padding()
        Spacer()
    }

    private func addGame(gameName: String, clerkUserId: String) async {
        do {
            let game = try await conclave.createGame(
                name: gameName,
                clerkUserId: clerkUserId
            )
            try await conclave
                .connectToWebSocket(
                    gameId: game.id,
                    clerkUserId: clerkUserId
                )
            screenPath.append(Screen.onlineGame)
        } catch {
            print("Failed to create game: \(error)")
        }
    }

    private func joinGame(gameId: UUID, clerkUserId: String) async {
        do {
            try await conclave
                .connectToWebSocket(
                    gameId: gameId,
                    clerkUserId: clerkUserId
                )
            let game = try await conclave.loadGame(gameId: gameId)
            print("HELLO! \(game.name)")
            do {
                let _ = try await conclave.joinGame(
                    gameId: game.id,
                    clerkUserId: clerkUserId
                )
            } catch {
                print("Joining an existing game: \(error)")
            }
            screenPath.append(Screen.onlineGame)
        } catch {
            print("Failed to join game: \(error)")
        }
    }

    private func getAllGames() async {
        do {
            _ = try await conclave.getAllGames()
        } catch {
            print("Failed to fetch games: \(error)")
        }
    }
}

#Preview {
    @Previewable @State var mockManager: ConclaveClientManager =
        ConclaveClientManager(client: MockConclaveClient.testing)
    GameListView(screenPath: .constant(NavigationPath())).environment(
        mockManager
    )
}
