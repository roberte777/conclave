import ConclaveKit
import SwiftUI

struct FourPlayerGameView: View {
    @Binding var screenPath: NavigationPath
    @State var mockManager: ConclaveClientManager =
    ConclaveClientManager(client: MockConclaveClient.testing).self

    var body: some View {
        if mockManager.isConnectedToWebSocket {
            ZStack {
                if mockManager.currentGame != nil {
                    if (mockManager.allPlayers.count == 4){
                        VStack {
                            HStack {
                                UserHealthView(
                                    mockManager.allPlayers[0],
                                    .blue,
                                    lifeOrientation: .Left
                                ).environment(mockManager)
                                UserHealthView(
                                    mockManager.allPlayers[1],
                                    .red,
                                    lifeOrientation: .Right
                                ).environment(mockManager)
                            }
                            HStack {
                                UserHealthView(
                                    mockManager.allPlayers[2],
                                    .yellow,
                                    lifeOrientation: .Left
                                ).environment(mockManager)
                                UserHealthView(
                                    mockManager.allPlayers[3],
                                    .green,
                                    lifeOrientation: .Right
                                ).environment(mockManager)
                            }
                        }
                        .padding()
                        Button(action: {
                            screenPath = NavigationPath()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.primary)
                                .fontWeight(.bold)
                                .padding(10)
                                .background(Circle().fill(.background))
                        }
                    }
                }
            }
        } else {
            ProgressView()
                .progressViewStyle(.circular)
                .task {
                    do {
                        print("attempting to create")
                        let game = try await mockManager.createGame(
                            name: "MyGame",
                            clerkUserId: "MyUser"
                        )
                        print("game created")
                        try await mockManager
                            .connectToWebSocket(
                                gameId: game.id,
                                clerkUserId: "MyUser"
                            )
                        print("player (me) added")
                        _ = try await mockManager.joinGame(
                            gameId: game.id,
                            clerkUserId: "Guest1"
                        )
                        print("player (Guest1) added")
                        _ = try await mockManager.joinGame(
                            gameId: game.id,
                            clerkUserId: "Guest2"
                        )
                        print("player (Guest2) added")
                        _ = try await mockManager.joinGame(
                            gameId: game.id,
                            clerkUserId: "Guest3"
                        )
                        print("player (Guest3) added")
                    } catch {
                        print("Failed to create game: \(error)")
                    }
                }
        }
    }
}

#Preview {
    FourPlayerGameView(screenPath: .constant(NavigationPath()))
}
