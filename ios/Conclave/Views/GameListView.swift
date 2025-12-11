import Clerk
import ConclaveKit
import SwiftUI

struct GameListView: View {
    @Binding var screenPath: NavigationPath
    @Environment(ConclaveClientManager.self) private var conclave
    @Environment(\.clerk) private var clerk
    @State private var showCreateSheet = false
    @State private var selectedStartingLife: Int32 = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: {
                    showCreateSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Game")
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .sheet(isPresented: $showCreateSheet) {
                    CreateGameSheet(
                        startingLife: $selectedStartingLife,
                        onCreate: { startingLife in
                            Task {
                                await addGame(startingLife: startingLife)
                            }
                        }
                    )
                    .presentationDetents([.medium])
                }
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

            Text("Available Games")
                .font(.title)
                .bold()
            
            if conclave.allGames.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No games available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Create a new game to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(conclave.allGames) { item in
                    Button(action: {
                        Task {
                            await joinGame(gameId: item.game.id)
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Game #\(item.game.id.uuidString.prefix(8))")
                                    .font(.headline)
                                HStack(spacing: 12) {
                                    Label("\(item.game.startingLife)", systemImage: "heart.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Label("\(item.users.count) players", systemImage: "person.2.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(item.game.status.rawValue.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(item.game.status == .active ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                                        .foregroundColor(item.game.status == .active ? .green : .gray)
                                        .cornerRadius(4)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }

        }
        .padding()
        Spacer()
    }

    private func setupAuthAndFetchGames() async {
        // Get token from Clerk and set it on the manager
        // Try to use the "default" template to match web frontend
        // If the template doesn't exist, fall back to the regular session token
        if let session = clerk.session {
            do {
                // First try with the "default" template (matches web frontend)
                if let token = try? await session.getToken(.init(template: "default")) {
                    await conclave.setAuthToken(token.jwt)
                } else {
                    // Fall back to regular session token
                    let token = try await session.getToken()
                    await conclave.setAuthToken(token?.jwt)
                }
            } catch {
                print("Failed to get auth token: \(error)")
            }
        }
        await getAllGames()
    }

    private func addGame(startingLife: Int32) async {
        do {
            let game = try await conclave.createGame(startingLife: startingLife)
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
            print("Joining game: \(game.id)")
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

// MARK: - Create Game Sheet
struct CreateGameSheet: View {
    @Binding var startingLife: Int32
    let onCreate: (Int32) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let lifeOptions: [Int32] = [20, 30, 40, 60]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Starting Life")
                        .font(.headline)
                    Text("Choose the starting life total for all players")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                HStack(spacing: 12) {
                    ForEach(lifeOptions, id: \.self) { life in
                        Button(action: {
                            startingLife = life
                        }) {
                            VStack(spacing: 4) {
                                Text("\(life)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text("Life")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(startingLife == life ? Color.accentColor : Color(.systemGray5))
                            .foregroundColor(startingLife == life ? .white : .primary)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                
                VStack(spacing: 8) {
                    Text("Format Suggestions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 16) {
                        Label("Standard: 20", systemImage: "rectangle.stack")
                            .font(.caption2)
                        Label("Commander: 40", systemImage: "crown")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    onCreate(startingLife)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Create Game")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
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
