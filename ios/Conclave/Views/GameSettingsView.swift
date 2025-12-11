import ConclaveKit
import SwiftUI

struct GameSettingsView: View {
    @Binding var screenPath: NavigationPath
    @Environment(ConclaveClientManager.self) private var conclave
    @State private var showEndGameSheet = false
    @State private var selectedWinnerId: UUID?
    @State private var showLeaveConfirmation = false

    var body: some View {
        if let currentGame = conclave.currentGame {
            List {
                // Game Info Section
                Section {
                    HStack {
                        Text("Game ID")
                        Spacer()
                        Text(String(currentGame.id.uuidString.prefix(8)))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(currentGame.status.rawValue.capitalized)
                            .foregroundColor(currentGame.status == .active ? .green : .secondary)
                    }
                    
                    HStack {
                        Text("Starting Life")
                        Spacer()
                        Text("\(currentGame.startingLife)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Players")
                        Spacer()
                        Text("\(conclave.allPlayers.count)")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Game Information")
                }
                
                // Players Section
                if !conclave.allPlayers.isEmpty {
                    Section {
                        ForEach(conclave.allPlayers, id: \.id) { player in
                            HStack {
                                if let imageUrl = player.imageUrl, let url = URL(string: imageUrl) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.secondary.opacity(0.2))
                                    }
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Text(String(player.displayName.prefix(1)).uppercased())
                                                .font(.caption)
                                                .fontWeight(.bold)
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(player.displayName)
                                        .font(.subheadline)
                                    if player.id == conclave.currentPlayer?.id {
                                        Text("You")
                                            .font(.caption)
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                
                                Spacer()
                                
                                Text("\(player.currentLife)")
                                    .font(.headline)
                                    .foregroundColor(player.currentLife <= 0 ? .red : .primary)
                            }
                        }
                    } header: {
                        Text("Players")
                    }
                }
                
                // Actions Section
                Section {
                    if currentGame.status == .active {
                        Button(action: {
                            showEndGameSheet = true
                        }) {
                            HStack {
                                Image(systemName: "flag.checkered")
                                Text("End Game")
                            }
                        }
                    }
                    
                    Button(action: {
                        showLeaveConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Leave Game")
                        }
                        .foregroundColor(.red)
                    }
                } header: {
                    Text("Actions")
                }
                
                // Winner Section (if game is finished)
                if let winner = conclave.winner {
                    Section {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text(winner.displayName)
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(winner.currentLife) life")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Winner")
                    }
                }
            }
            .navigationTitle("Game Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEndGameSheet) {
                EndGameSettingsSheet(
                    players: conclave.allPlayers,
                    selectedWinnerId: $selectedWinnerId,
                    onConfirm: {
                        Task {
                            await endGame()
                        }
                    }
                )
                .presentationDetents([.medium])
            }
            .alert("Leave Game", isPresented: $showLeaveConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Leave", role: .destructive) {
                    leaveGame()
                }
            } message: {
                Text("Are you sure you want to leave this game?")
            }
        } else {
            VStack {
                Image(systemName: "gamecontroller")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No active game")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func endGame() async {
        guard conclave.currentGame != nil else {
            return
        }

        do {
            try await conclave.sendEndGame(winnerPlayerId: selectedWinnerId)
            showEndGameSheet = false
        } catch {
            print("Failed to end game: \(error)")
        }
    }

    private func leaveGame() {
        guard let currentGame = conclave.currentGame else {
            return
        }

        Task {
            do {
                try await conclave.leaveGame(
                    gameId: currentGame.id
                )

                conclave.clearCurrentGame()
                screenPath = NavigationPath()
            } catch {
                print("Failed to leave game: \(error)")
            }
        }
    }
}

// MARK: - End Game Settings Sheet

struct EndGameSettingsSheet: View {
    let players: [Player]
    @Binding var selectedWinnerId: UUID?
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Select the winner of this game, or choose \"No winner\" if the game was not completed.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top)
                
                ScrollView {
                    VStack(spacing: 8) {
                        // No winner option
                        Button(action: {
                            selectedWinnerId = nil
                        }) {
                            HStack {
                                Image(systemName: selectedWinnerId == nil ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedWinnerId == nil ? .accentColor : .secondary)
                                Text("No winner (game not completed)")
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedWinnerId == nil ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedWinnerId == nil ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Player options
                        ForEach(players, id: \.id) { player in
                            Button(action: {
                                selectedWinnerId = player.id
                            }) {
                                HStack {
                                    Image(systemName: selectedWinnerId == player.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedWinnerId == player.id ? .accentColor : .secondary)
                                    
                                    if let imageUrl = player.imageUrl, let url = URL(string: imageUrl) {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Circle()
                                                .fill(Color.secondary.opacity(0.2))
                                        }
                                        .frame(width: 24, height: 24)
                                        .clipShape(Circle())
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("P\(player.position): \(player.displayName)")
                                            .foregroundColor(.primary)
                                        Text("\(player.currentLife) life")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedWinnerId == player.id ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedWinnerId == player.id ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                    
                    Button(action: {
                        onConfirm()
                    }) {
                        Text("End Game")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("End Game")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    @Previewable @State var mockManager: ConclaveClientManager = {
        let manager = ConclaveClientManager(client: MockConclaveClient.testing)

        // Setup mock game state for preview
        let mockGame = Game(
            id: UUID(),
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
            position: 1
        )

        manager.currentGame = mockGame
        manager.currentPlayer = mockPlayer

        return manager
    }()

    GameSettingsView(screenPath: .constant(NavigationPath()))
        .environment(mockManager)
}
