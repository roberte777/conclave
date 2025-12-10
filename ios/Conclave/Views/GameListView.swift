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
                            Task {
                                await addGame(gameName: newGameName)
                                newGameName = ""
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
                await setupAuthAndFetchGames()
            }
            .padding(.bottom, 16)

            Text("Game List")
                .font(.title)
                .bold()
            ForEach(conclave.allGames) { item in
                Button(action: {
                    Task {
                        await joinGame(gameId: item.game.id)
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

    private func setupAuthAndFetchGames() async {
        // Get token from Clerk and set it on the manager
        if let session = clerk.session {
            do {
                let token = try await session.getToken()
                await conclave.setAuthToken(token?.jwt)
            } catch {
                print("Failed to get auth token: \(error)")
            }
        }
        await getAllGames()
    }

    private func addGame(gameName: String) async {
        do {
            let game = try await conclave.createGame(name: gameName)
            try await conclave.connectToWebSocket(gameId: game.id)
            screenPath.append(Screen.onlineGame)
        } catch {
            print("Failed to create game: \(error)")
        }
    }

    private func joinGame(gameId: UUID) async {
        do {
            try await conclave.connectToWebSocket(gameId: gameId)
            let game = try await conclave.loadGame(gameId: gameId)
            print("HELLO! \(game.name)")
            do {
                let _ = try await conclave.joinGame(gameId: game.id)
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
