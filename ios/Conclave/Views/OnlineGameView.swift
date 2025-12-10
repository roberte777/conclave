import ConclaveKit
import SwiftUI

struct OnlineGameView: View {
    @Binding var screenPath: NavigationPath
    @Environment(ConclaveClientManager.self) private var conclave

    var body: some View {
        // Current Game Info
        if let game = conclave.currentGame {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack {
                        Text("📋 \(game.name)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Status: \(game.status.rawValue.capitalized)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Starting Life: \(game.startingLife)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                    Button(action: {
                        screenPath.append(Screen.gameSettings)
                    }) {
                        Image(systemName: "gear")
                            .foregroundColor(.primary)
                            .fontWeight(.bold)
                            .padding(10)
                            .background(Circle().fill(.background))
                    }
                }
                playerContainer
            }
        } else {
            Text("No active game")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }

    }

    @ViewBuilder
    private var playerContainer: some View {
        switch conclave.allPlayers.count {
        case 1:
            UserHealthView(
                conclave.allPlayers[0],
                .blue,
                lifeOrientation: .Left
            )
        case 2:
            VStack {
                UserHealthView(
                    conclave.allPlayers[0],
                    .blue,
                    lifeOrientation: .Down
                )
                UserHealthView(
                    conclave.allPlayers[1],
                    .red,
                    lifeOrientation: .Up
                )
            }
        case 3:
            VStack {
                UserHealthView(
                    conclave.allPlayers[0],
                    .blue,
                    lifeOrientation: .Down
                )
                HStack {
                    UserHealthView(
                        conclave.allPlayers[1],
                        .red,
                        lifeOrientation: .Left
                    )
                    UserHealthView(
                        conclave.allPlayers[2],
                        .yellow,
                        lifeOrientation: .Right
                    )
                }
            }
        case 4:
            VStack {
                HStack {
                    UserHealthView(
                        conclave.allPlayers[0],
                        .blue,
                        lifeOrientation: .Left
                    )
                    UserHealthView(
                        conclave.allPlayers[1],
                        .red,
                        lifeOrientation: .Right
                    )
                }
                HStack {
                    UserHealthView(
                        conclave.allPlayers[2],
                        .yellow,
                        lifeOrientation: .Left
                    )
                    UserHealthView(
                        conclave.allPlayers[3],
                        .green,
                        lifeOrientation: .Right
                    )
                }
            }
        default:
            Text("No Players")
        }
    }
}

#Preview {
    @Previewable @State var mockManager: ConclaveClientManager =
        ConclaveClientManager(client: MockConclaveClient.testing)
    if mockManager.isConnectedToWebSocket {
        HStack {
            OnlineGameView(screenPath: .constant(NavigationPath()))
                .environment(mockManager)
        }
    } else {
        ProgressView()
            .progressViewStyle(.circular)
            .task {
                do {
                    await mockManager.setAuthToken("mock_token")
                    let game = try await mockManager.createGame(name: "MyGame")
                    try await mockManager.connectToWebSocket(gameId: game.id)
                } catch {
                    print("Failed to create game: \(error)")
                }
            }
    }
}
