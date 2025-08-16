import ConclaveKit
import SwiftUI

struct GameListView: View {
    @Binding var screenPath: NavigationPath
    @Environment(ConclaveClientManager.self) private var conclave

    @State private var showCreateAlert = false
    @State private var showJoinAlert = false
    @State private var newGameName = ""
    @State private var newUserName = ""

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
                        TextField("User Name", text: $newUserName)
                        Button("Create") {
                            Task {
                                await addGame(
                                    gameName: newGameName,
                                    userName: newUserName
                                )
                                newGameName = ""
                                newUserName = ""

                            }
                        }
                        Button("Cancel", role: .cancel) {
                            newGameName = ""
                            newUserName = ""
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
                    showJoinAlert = true
                }) {
                    Text(item.game.name)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .alert(
                    "Join Game",
                    isPresented: $showJoinAlert,
                    actions: {
                        TextField("User Name", text: $newUserName)
                        Button("Submit") {
                            Task {
                                await joinGame(
                                    gameId: item.game.id,
                                    userName: newUserName
                                )
                                newUserName = ""
                            }
                        }
                        Button("Cancel", role: .cancel) {
                            newUserName = ""
                        }
                    },
                    message: {
                        Text("Enter your name")
                    }
                )
            }

        }
        .padding()
        Spacer()
    }

    private func addGame(gameName: String, userName: String) async {
        do {
            let game = try await conclave.createGame(
                name: gameName,
                clerkUserId: userName
            )
            try await conclave
                .connectToWebSocket(
                    gameId: game.id,
                    clerkUserId: userName
                )
            screenPath.append(Screen.onlineGame)
        } catch {
            print("Failed to create game: \(error)")
        }
    }

    private func joinGame(gameId: UUID, userName: String) async {
        do {
            let game = try await conclave.joinGame(
                gameId: gameId,
                clerkUserId: userName
            )
            try await conclave
                .connectToWebSocket(
                    gameId: game.id,
                    clerkUserId: userName
                )
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
