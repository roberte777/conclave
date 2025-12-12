import ConclaveKit
import SwiftUI

struct GameSettingsView: View {
    @Binding var screenPath: NavigationPath
    @Environment(ConclaveClientManager.self) private var conclave
    @State private var showEndGameSheet = false
    @State private var selectedWinnerId: UUID?
    @State private var showLeaveConfirmation = false

    var body: some View {
        ZStack {
            ConclaveGradientBackground()
            
            if let currentGame = conclave.currentGame {
                ScrollView {
                    VStack(spacing: 20) {
                        // Game Info Section
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Game Information", icon: "info.circle.fill")
                            
                            VStack(spacing: 0) {
                                SettingsRow(label: "Game ID", value: String(currentGame.id.uuidString.prefix(8)))
                                Divider().background(Color.white.opacity(0.1))
                                SettingsRow(
                                    label: "Status",
                                    value: currentGame.status.rawValue.capitalized,
                                    valueColor: currentGame.status == .active ? .conclaveSuccess : .conclaveMuted
                                )
                                Divider().background(Color.white.opacity(0.1))
                                SettingsRow(label: "Starting Life", value: "\(currentGame.startingLife)")
                                Divider().background(Color.white.opacity(0.1))
                                SettingsRow(label: "Players", value: "\(conclave.allPlayers.count)")
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        
                        // Players Section
                        if !conclave.allPlayers.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeader(title: "Players", icon: "person.2.fill")
                                
                                VStack(spacing: 0) {
                                    ForEach(Array(conclave.allPlayers.enumerated()), id: \.element.id) { index, player in
                                        if index > 0 {
                                            Divider().background(Color.white.opacity(0.1))
                                        }
                                        PlayerSettingsRow(
                                            player: player,
                                            isCurrentUser: player.id == conclave.currentPlayer?.id
                                        )
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                        
                        // Winner Section (if game is finished)
                        if let winner = conclave.winner {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeader(title: "Winner", icon: "crown.fill", iconColor: .yellow)
                                
                                HStack(spacing: 12) {
                                    Image(systemName: "crown.fill")
                                        .foregroundColor(.yellow)
                                        .font(.title2)
                                    
                                    Text(winner.displayName)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text("\(winner.currentLife) life")
                                        .foregroundColor(.conclaveMuted)
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.yellow.opacity(0.15), Color.orange.opacity(0.08)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        
                        // Actions Section
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Actions", icon: "bolt.fill")
                            
                            VStack(spacing: 12) {
                                if currentGame.status == .active {
                                    Button(action: {
                                        showEndGameSheet = true
                                    }) {
                                        HStack {
                                            Image(systemName: "flag.checkered")
                                                .font(.system(size: 16, weight: .semibold))
                                            Text("End Game")
                                                .fontWeight(.semibold)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.white)
                                        .padding(16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.conclaveViolet, .conclavePink],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                        )
                                    }
                                }
                                
                                Button(action: {
                                    showLeaveConfirmation = true
                                }) {
                                    HStack {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("Leave Game")
                                            .fontWeight(.semibold)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.conclaveDanger)
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.conclaveDanger.opacity(0.12))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.conclaveDanger.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.conclaveViolet.opacity(0.5), .conclavePink.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("No active game")
                        .font(.headline)
                        .foregroundColor(.conclaveMuted)
                }
            }
        }
        .navigationTitle("Game Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.conclaveBackground.opacity(0.9), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
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

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let icon: String
    var iconColor: Color = .conclaveViolet
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(iconColor)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.conclaveMuted)
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let label: String
    let value: String
    var valueColor: Color = .conclaveMuted
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Player Settings Row
struct PlayerSettingsRow: View {
    let player: Player
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if let imageUrl = player.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            } else {
                Circle()
                    .fill(Color.conclaveViolet.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(player.displayName.prefix(1)).uppercased())
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.conclaveViolet)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(player.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                if isCurrentUser {
                    Text("You")
                        .font(.caption)
                        .foregroundColor(.conclaveViolet)
                }
            }
            
            Spacer()
            
            Text("\(player.currentLife)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(player.currentLife <= 0 ? .conclaveDanger : .white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
            ZStack {
                ConclaveGradientBackground()
                
                VStack(spacing: 16) {
                    Text("Select the winner of this game, or choose \"No winner\" if the game was not completed.")
                        .font(.subheadline)
                        .foregroundColor(.conclaveMuted)
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
                                        .foregroundColor(selectedWinnerId == nil ? .conclaveViolet : .conclaveMuted)
                                    Text("No winner (game not completed)")
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedWinnerId == nil ? Color.conclaveViolet.opacity(0.15) : Color.white.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedWinnerId == nil ? Color.conclaveViolet.opacity(0.5) : Color.white.opacity(0.1), lineWidth: selectedWinnerId == nil ? 2 : 1)
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
                                            .foregroundColor(selectedWinnerId == player.id ? .conclaveViolet : .conclaveMuted)
                                        
                                        if let imageUrl = player.imageUrl, let url = URL(string: imageUrl) {
                                            AsyncImage(url: url) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Circle()
                                                    .fill(Color.white.opacity(0.1))
                                            }
                                            .frame(width: 24, height: 24)
                                            .clipShape(Circle())
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("P\(player.position): \(player.displayName)")
                                                .foregroundColor(.white)
                                            Text("\(player.currentLife) life")
                                                .font(.caption)
                                                .foregroundColor(.conclaveMuted)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedWinnerId == player.id ? Color.conclaveViolet.opacity(0.15) : Color.white.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedWinnerId == player.id ? Color.conclaveViolet.opacity(0.5) : Color.white.opacity(0.1), lineWidth: selectedWinnerId == player.id ? 2 : 1)
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
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.08))
                        )
                        .foregroundColor(.white)
                        
                        Button(action: {
                            onConfirm()
                        }) {
                            Text("End Game")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.conclaveDanger)
                        )
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("End Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.conclaveBackground.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
