import ConclaveKit
import SwiftUI

struct OnlineGameView: View {
    @Binding var screenPath: NavigationPath
    @Environment(ConclaveClientManager.self) private var conclave

    var body: some View {
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
                    let game = try await mockManager.createGame(
                        name: "MyGame",
                        clerkUserId: "MyUser"
                    )
                    try await mockManager
                        .connectToWebSocket(
                            gameId: game.id,
                            clerkUserId: "MyUser"
                        )
                    _ = try await mockManager.joinGame(
                        gameId: game.id,
                        clerkUserId: "Guest1"
                    )
                    _ = try await mockManager.joinGame(
                        gameId: game.id,
                        clerkUserId: "Guest2"
                    )
                    _ = try await mockManager.joinGame(
                        gameId: game.id,
                        clerkUserId: "Guest3"
                    )
                } catch {
                    print("Failed to create game: \(error)")
                }
            }
    }
}
