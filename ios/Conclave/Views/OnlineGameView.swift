import ConclaveKit
import SwiftUI

struct OnlineGameView: View {
    @Binding var screenPath: NavigationPath
    @Environment(ConclaveClientManager.self) private var conclave
    @State private var expandedPlayerId: UUID?
    @State private var showEndGameSheet = false
    @State private var selectedWinnerId: UUID?
    @State private var animatingLifePlayerIds: Set<UUID> = []
    
    private let playerColors: [Color] = [
        .purple, .blue, .green, .orange, .red, .pink, .teal, .indigo
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Winner Banner
            if let winner = conclave.winner {
                winnerBanner(winner: winner)
            }
            
            // Main Content
            if let game = conclave.currentGame {
                if conclave.allPlayers.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        playerGrid
                            .padding()
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text("No active game")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showEndGameSheet) {
            EndGameSheet(
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
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let game = conclave.currentGame {
                    Text("Game #\(game.id.uuidString.prefix(8))")
                        .font(.headline)
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(conclave.isConnectedToWebSocket ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(conclave.isConnectedToWebSocket ? "Live" : "Connecting...")
                                .font(.caption)
                                .foregroundColor(conclave.isConnectedToWebSocket ? .green : .red)
                        }
                        
                        Label("\(conclave.allPlayers.count) players", systemImage: "person.2")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Refresh button
            Button(action: {
                Task {
                    try? await conclave.requestGameState()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(8)
                    .background(Circle().fill(Color(.systemGray5)))
            }
            .disabled(!conclave.isConnectedToWebSocket)
            
            // End game button
            Button(action: {
                showEndGameSheet = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                    Text("End")
                }
                .font(.subheadline)
                .foregroundColor(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            .disabled(!conclave.isConnectedToWebSocket || conclave.currentGame?.status == .finished)
            
            // Settings button
            Button(action: {
                screenPath.append(Screen.gameSettings)
            }) {
                Image(systemName: "gear")
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(8)
                    .background(Circle().fill(Color(.systemGray5)))
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Winner Banner
    
    private func winnerBanner(winner: Player) -> some View {
        HStack {
            Image(systemName: "crown.fill")
                .foregroundColor(.yellow)
            Text("\(winner.displayName) wins with \(winner.currentLife) life!")
                .fontWeight(.semibold)
            Image(systemName: "crown.fill")
                .foregroundColor(.yellow)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.2), Color.orange.opacity(0.2)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Waiting for players...")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    // MARK: - Player Grid
    
    private var playerGrid: some View {
        LazyVGrid(
            columns: gridColumns,
            spacing: 16
        ) {
            ForEach(Array(conclave.allPlayers.enumerated()), id: \.element.id) { index, player in
                PlayerCard(
                    player: player,
                    color: playerColors[index % playerColors.count],
                    isExpanded: expandedPlayerId == player.id,
                    isAnimating: animatingLifePlayerIds.contains(player.id),
                    totalCommanderDamage: conclave.getTotalCommanderDamage(toPlayerId: player.id),
                    hasPartner: conclave.hasPartner(playerId: player.id),
                    otherPlayers: conclave.allPlayers.filter { $0.id != player.id },
                    onExpandToggle: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedPlayerId = expandedPlayerId == player.id ? nil : player.id
                        }
                    },
                    onLifeChange: { amount in
                        Task {
                            await changeLife(playerId: player.id, amount: amount)
                        }
                    },
                    onTogglePartner: {
                        Task {
                            await togglePartner(playerId: player.id)
                        }
                    },
                    onCommanderDamageChange: { fromId, commanderNum, amount in
                        Task {
                            await changeCommanderDamage(fromPlayerId: fromId, toPlayerId: player.id, commanderNumber: commanderNum, amount: amount)
                        }
                    },
                    getCommanderDamage: { fromId, commanderNum in
                        conclave.getCommanderDamage(fromPlayerId: fromId, toPlayerId: player.id, commanderNumber: commanderNum)
                    },
                    playerHasPartner: { playerId in
                        conclave.hasPartner(playerId: playerId)
                    }
                )
            }
        }
    }
    
    private var gridColumns: [GridItem] {
        let count = conclave.allPlayers.count
        switch count {
        case 1:
            return [GridItem(.flexible())]
        case 2:
            return [GridItem(.flexible())]
        default:
            return [GridItem(.flexible()), GridItem(.flexible())]
        }
    }
    
    // MARK: - Actions
    
    private func changeLife(playerId: UUID, amount: Int32) async {
        do {
            animatingLifePlayerIds.insert(playerId)
            try await conclave.sendLifeUpdate(playerId: playerId, changeAmount: amount)
            
            // Remove animation after delay
            try? await Task.sleep(nanoseconds: 200_000_000)
            animatingLifePlayerIds.remove(playerId)
        } catch {
            print("Failed to update life: \(error)")
            animatingLifePlayerIds.remove(playerId)
        }
    }
    
    private func togglePartner(playerId: UUID) async {
        do {
            let currentlyEnabled = conclave.hasPartner(playerId: playerId)
            try await conclave.sendTogglePartner(playerId: playerId, enablePartner: !currentlyEnabled)
        } catch {
            print("Failed to toggle partner: \(error)")
        }
    }
    
    private func changeCommanderDamage(fromPlayerId: UUID, toPlayerId: UUID, commanderNumber: Int32, amount: Int32) async {
        do {
            try await conclave.sendCommanderDamageUpdate(
                fromPlayerId: fromPlayerId,
                toPlayerId: toPlayerId,
                commanderNumber: commanderNumber,
                damageAmount: amount
            )
        } catch {
            print("Failed to update commander damage: \(error)")
        }
    }
    
    private func endGame() async {
        do {
            try await conclave.sendEndGame(winnerPlayerId: selectedWinnerId)
            showEndGameSheet = false
        } catch {
            print("Failed to end game: \(error)")
        }
    }
}

// MARK: - Player Card

struct PlayerCard: View {
    let player: Player
    let color: Color
    let isExpanded: Bool
    let isAnimating: Bool
    let totalCommanderDamage: Int32
    let hasPartner: Bool
    let otherPlayers: [Player]
    let onExpandToggle: () -> Void
    let onLifeChange: (Int32) -> Void
    let onTogglePartner: () -> Void
    let onCommanderDamageChange: (UUID, Int32, Int32) -> Void
    let getCommanderDamage: (UUID, Int32) -> Int32
    let playerHasPartner: (UUID) -> Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                // Avatar
                if let imageUrl = player.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        avatarPlaceholder
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    avatarPlaceholder
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text("Player \(player.position)")
                        .font(.caption2)
                        .foregroundColor(color)
                }
                
                Spacer()
                
                // Partner toggle
                Button(action: onTogglePartner) {
                    Image(systemName: "shield.fill")
                        .font(.body)
                        .foregroundColor(hasPartner ? color : .secondary.opacity(0.5))
                        .padding(8)
                        .background(
                            Circle()
                                .fill(hasPartner ? color.opacity(0.2) : Color(.systemGray5))
                        )
                }
                
                // Commander damage toggle
                Button(action: onExpandToggle) {
                    Image(systemName: "burst.fill")
                        .font(.body)
                        .foregroundColor(isExpanded ? color : .secondary.opacity(0.5))
                        .padding(8)
                        .background(
                            Circle()
                                .fill(isExpanded ? color.opacity(0.2) : Color(.systemGray5))
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .opacity(0.3)
            
            // Life Counter
            HStack {
                // Decrease buttons
                VStack(spacing: 8) {
                    lifeButton(amount: -1, isDecrease: true)
                    lifeButton(amount: -5, isDecrease: true, showNumber: true)
                }
                
                // Life total
                VStack(spacing: 4) {
                    Text("\(player.currentLife)")
                        .font(.system(size: 72, weight: .black))
                        .foregroundColor(lifeColor)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(.easeOut(duration: 0.1), value: isAnimating)
                    
                    HStack(spacing: 12) {
                        Text("Life")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if totalCommanderDamage > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "burst.fill")
                                    .font(.caption2)
                                Text("\(totalCommanderDamage)")
                                    .font(.caption)
                            }
                            .foregroundColor(.orange)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Increase buttons
                VStack(spacing: 8) {
                    lifeButton(amount: 1, isDecrease: false)
                    lifeButton(amount: 5, isDecrease: false, showNumber: true)
                }
            }
            .padding()
            
            // Commander Damage Section (Expanded)
            if isExpanded && !otherPlayers.isEmpty {
                Divider()
                    .opacity(0.3)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "burst.fill")
                            .foregroundColor(.orange)
                        Text("Incoming Commander Damage")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(otherPlayers, id: \.id) { fromPlayer in
                            CommanderDamageRow(
                                fromPlayer: fromPlayer,
                                hasPartner: playerHasPartner(fromPlayer.id),
                                getCommanderDamage: { cmdNum in
                                    getCommanderDamage(fromPlayer.id, cmdNum)
                                },
                                onDamageChange: { cmdNum, amount in
                                    onCommanderDamageChange(fromPlayer.id, cmdNum, amount)
                                }
                            )
                        }
                    }
                }
                .padding()
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.15), color.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(color.opacity(0.2))
            .frame(width: 36, height: 36)
            .overlay(
                Text(String(player.displayName.prefix(1)).uppercased())
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            )
    }
    
    private var lifeColor: Color {
        if player.currentLife <= 5 {
            return .red
        } else if player.currentLife <= 10 {
            return .orange
        }
        return .primary
    }
    
    @ViewBuilder
    private func lifeButton(amount: Int32, isDecrease: Bool, showNumber: Bool = false) -> some View {
        Button(action: {
            onLifeChange(amount)
        }) {
            Group {
                if showNumber {
                    Text(amount > 0 ? "+\(amount)" : "\(amount)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                } else {
                    Image(systemName: isDecrease ? "chevron.down" : "chevron.up")
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }
            .foregroundColor(isDecrease ? .red : .green)
            .frame(width: 48, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDecrease ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
            )
        }
    }
}

// MARK: - Commander Damage Row

struct CommanderDamageRow: View {
    let fromPlayer: Player
    let hasPartner: Bool
    let getCommanderDamage: (Int32) -> Int32
    let onDamageChange: (Int32, Int32) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Player header
            HStack(spacing: 6) {
                if let imageUrl = fromPlayer.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.secondary.opacity(0.2))
                    }
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text(String(fromPlayer.displayName.prefix(1)))
                                .font(.caption2)
                                .fontWeight(.bold)
                        )
                }
                
                Text(fromPlayer.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            
            // Commander damage controls
            ForEach(1...(hasPartner ? 2 : 1), id: \.self) { cmdNum in
                commanderDamageControl(commanderNumber: Int32(cmdNum))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }
    
    private func commanderDamageControl(commanderNumber: Int32) -> some View {
        let damage = getCommanderDamage(commanderNumber)
        
        return HStack {
            Text("Cmdr \(commanderNumber)")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: {
                    onDamageChange(commanderNumber, -1)
                }) {
                    Text("-")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 24, height: 24)
                        .background(Color(.systemGray5))
                        .cornerRadius(6)
                }
                .disabled(damage <= 0)
                .opacity(damage <= 0 ? 0.3 : 1)
                
                Text("\(damage)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(damageColor(damage))
                    .frame(width: 24)
                
                Button(action: {
                    onDamageChange(commanderNumber, 1)
                }) {
                    Text("+")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 24, height: 24)
                        .background(Color(.systemGray5))
                        .cornerRadius(6)
                }
            }
        }
    }
    
    private func damageColor(_ damage: Int32) -> Color {
        if damage >= 21 {
            return .red
        } else if damage >= 15 {
            return .orange
        }
        return .primary
    }
}

// MARK: - End Game Sheet

struct EndGameSheet: View {
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
                    let game = try await mockManager.createGame(startingLife: 40)
                    try await mockManager.connectToWebSocket(gameId: game.id)
                } catch {
                    print("Failed to create game: \(error)")
                }
            }
    }
}
