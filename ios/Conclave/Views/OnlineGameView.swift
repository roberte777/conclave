import ConclaveKit
import SwiftUI

struct OnlineGameView: View {
    @Binding var screenPath: NavigationPath
    @Environment(ConclaveClientManager.self) private var conclave
    @State private var showEndGameSheet = false
    @State private var selectedWinnerId: UUID?
    @State private var animatingLifePlayerIds: Set<UUID> = []
    @State private var trackingPlayerId: UUID?
    @State private var poisonCounters: [UUID: Int32] = [:]
    
    // Separate logged-in player from other players
    private var loggedInPlayer: Player? {
        conclave.currentPlayer
    }
    
    private var otherPlayers: [Player] {
        guard let currentPlayer = conclave.currentPlayer else {
            return conclave.allPlayers
        }
        return conclave.allPlayers.filter { $0.id != currentPlayer.id }
    }
    
    var body: some View {
        ZStack {
            // Background
            ConclaveGradientBackground()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Winner Banner
                if let winner = conclave.winner {
                    winnerBanner(winner: winner)
                }
                
                // Main Content
                if conclave.currentGame != nil {
                    if conclave.allPlayers.isEmpty {
                        emptyStateView
                    } else {
                        ZStack(alignment: .bottom) {
                            // Scrollable area for other players - takes remaining space
                            ScrollView {
                                VStack(spacing: 12) {
                                    ForEach(Array(otherPlayers.enumerated()), id: \.element.id) { index, player in
                                        PlayerCardRow(
                                            player: player,
                                            colorIndex: playerColorIndex(for: player),
                                            isAnimating: animatingLifePlayerIds.contains(player.id),
                                            onLifeChange: { amount in
                                                Task {
                                                    await changeLife(playerId: player.id, amount: amount)
                                                }
                                            },
                                            onSettingsTap: {
                                                trackingPlayerId = player.id
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                .padding(.bottom, loggedInPlayer != nil ? 180 : 12) // Extra padding when logged-in player exists
                            }
                            
                            // Logged-in player STICKY at bottom
                            if let player = loggedInPlayer {
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 1)
                                    
                                    PlayerCardRow(
                                        player: player,
                                        colorIndex: playerColorIndex(for: player),
                                        isAnimating: animatingLifePlayerIds.contains(player.id),
                                        isCurrentUser: true,
                                        onLifeChange: { amount in
                                            Task {
                                                await changeLife(playerId: player.id, amount: amount)
                                            }
                                        },
                                        onSettingsTap: {
                                            trackingPlayerId = player.id
                                        }
                                    )
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .background(
                                    Color.conclaveBackground.opacity(0.95)
                                        .background(.ultraThinMaterial)
                                )
                            }
                        }
                    }
                } else {
                    VStack {
                        Spacer()
                        Text("No active game")
                            .font(.headline)
                            .foregroundColor(.conclaveMuted)
                        Spacer()
                    }
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
        .sheet(item: $trackingPlayerId) { playerId in
            if let player = conclave.allPlayers.first(where: { $0.id == playerId }) {
                PlayerTrackingPanel(
                    player: player,
                    colorIndex: playerColorIndex(for: player),
                    poisonCount: poisonCounters[playerId] ?? 0,
                    hasPartner: conclave.hasPartner(playerId: playerId),
                    otherPlayers: conclave.allPlayers.filter { $0.id != playerId },
                    onPoisonChange: { amount in
                        let current = poisonCounters[playerId] ?? 0
                        poisonCounters[playerId] = max(0, current + amount)
                    },
                    onTogglePartner: {
                        Task {
                            await togglePartner(playerId: playerId)
                        }
                    },
                    onCommanderDamageChange: { fromId, commanderNum, amount in
                        Task {
                            await changeCommanderDamage(
                                fromPlayerId: fromId,
                                toPlayerId: playerId,
                                commanderNumber: commanderNum,
                                amount: amount
                            )
                        }
                    },
                    getCommanderDamage: { fromId, commanderNum in
                        conclave.getCommanderDamage(
                            fromPlayerId: fromId,
                            toPlayerId: playerId,
                            commanderNumber: commanderNum
                        )
                    },
                    playerHasPartner: { pId in
                        conclave.hasPartner(playerId: pId)
                    }
                )
                .presentationDetents([.large])
            }
        }
    }
    
    // Get consistent color index for a player
    private func playerColorIndex(for player: Player) -> Int {
        if let index = conclave.allPlayers.firstIndex(where: { $0.id == player.id }) {
            return index
        }
        return 0
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: {
                screenPath = NavigationPath()
            }) {
                Image(systemName: "house.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(ConclaveIconButtonStyle())
            
            VStack(alignment: .leading, spacing: 2) {
                if let game = conclave.currentGame {
                    Text("Game #\(game.id.uuidString.prefix(8))")
                        .font(.headline)
                        .foregroundColor(.white)
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(conclave.isConnectedToWebSocket ? Color.conclaveSuccess : Color.conclaveDanger)
                                .frame(width: 8, height: 8)
                            Text(conclave.isConnectedToWebSocket ? "Live" : "Connecting...")
                                .font(.caption)
                                .foregroundColor(conclave.isConnectedToWebSocket ? .conclaveSuccess : .conclaveDanger)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10))
                            Text("\(conclave.allPlayers.count)")
                        }
                        .font(.caption)
                        .foregroundColor(.conclaveMuted)
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(ConclaveIconButtonStyle())
            .disabled(!conclave.isConnectedToWebSocket)
            .opacity(conclave.isConnectedToWebSocket ? 1 : 0.5)
            
            // End game button
            Button(action: {
                showEndGameSheet = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 12, weight: .semibold))
                    Text("End")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.conclaveDanger)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.conclaveDanger.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.conclaveDanger.opacity(0.3), lineWidth: 1)
                )
            }
            .disabled(!conclave.isConnectedToWebSocket || conclave.currentGame?.status == .finished)
            .opacity((!conclave.isConnectedToWebSocket || conclave.currentGame?.status == .finished) ? 0.5 : 1)
            
            // Settings button
            Button(action: {
                screenPath.append(Screen.gameSettings)
            }) {
                Image(systemName: "gear")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(ConclaveIconButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.conclaveBackground.opacity(0.8)
                .background(.ultraThinMaterial)
        )
    }
    
    // MARK: - Winner Banner
    
    private func winnerBanner(winner: Player) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .foregroundColor(.yellow)
            Text("\(winner.displayName) wins with \(winner.currentLife) life!")
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Image(systemName: "crown.fill")
                .foregroundColor(.yellow)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.25), Color.orange.opacity(0.2)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            Rectangle()
                .fill(Color.yellow.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundColor(.conclaveMuted)
            Text("Waiting for players...")
                .font(.headline)
                .foregroundColor(.conclaveMuted)
            Spacer()
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

// MARK: - Player Card Row

struct PlayerCardRow: View {
    let player: Player
    let colorIndex: Int
    let isAnimating: Bool
    var isCurrentUser: Bool = false
    let onLifeChange: (Int32) -> Void
    let onSettingsTap: () -> Void
    
    private var playerColor: (gradient: [Color], accent: Color, border: Color) {
        ConclavePlayerColors.color(for: colorIndex)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Top row: Avatar, Name, Settings
            HStack(spacing: 12) {
                // Avatar
                playerAvatar
                
                // Name
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    if isCurrentUser {
                        Text("You")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(playerColor.accent)
                    }
                }
                
                Spacer()
                
                // Settings button
                Button(action: onSettingsTap) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                }
            }
            
            // Bottom row: Life controls
            HStack(spacing: 0) {
                // Decrease buttons
                HStack(spacing: 8) {
                    Button(action: { onLifeChange(-5) }) {
                        Text("-5")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.conclaveDanger.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.conclaveDanger.opacity(0.12))
                            )
                    }
                    
                    Button(action: { onLifeChange(-1) }) {
                        Image(systemName: "minus")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.conclaveDanger)
                            .frame(width: 52, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.conclaveDanger.opacity(0.18))
                            )
                    }
                }
                
                Spacer()
                
                // Life total
                VStack(spacing: 2) {
                    Text("\(player.currentLife)")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(lifeColor)
                        .scaleEffect(isAnimating ? 1.08 : 1.0)
                        .animation(.easeOut(duration: 0.1), value: isAnimating)
                    Text("Life")
                        .font(.caption)
                        .foregroundColor(.conclaveMuted)
                }
                
                Spacer()
                
                // Increase buttons
                HStack(spacing: 8) {
                    Button(action: { onLifeChange(1) }) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.conclaveSuccess)
                            .frame(width: 52, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.conclaveSuccess.opacity(0.18))
                            )
                    }
                    
                    Button(action: { onLifeChange(5) }) {
                        Text("+5")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.conclaveSuccess.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.conclaveSuccess.opacity(0.12))
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: playerColor.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.conclaveCard.opacity(0.5))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isCurrentUser ? playerColor.accent.opacity(0.6) : playerColor.border, lineWidth: isCurrentUser ? 2 : 1)
        )
    }
    
    private var playerAvatar: some View {
        Group {
            if let imageUrl = player.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    avatarPlaceholder
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                )
            } else {
                avatarPlaceholder
            }
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(playerColor.accent.opacity(0.2))
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(player.displayName.prefix(1)).uppercased())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(playerColor.accent)
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
    
    private var lifeColor: Color {
        if player.currentLife <= 5 {
            return .conclaveDanger
        } else if player.currentLife <= 10 {
            return .orange
        }
        return .white
    }
}

// MARK: - Player Tracking Panel

struct PlayerTrackingPanel: View {
    let player: Player
    let colorIndex: Int
    let poisonCount: Int32
    let hasPartner: Bool
    let otherPlayers: [Player]
    let onPoisonChange: (Int32) -> Void
    let onTogglePartner: () -> Void
    let onCommanderDamageChange: (UUID, Int32, Int32) -> Void
    let getCommanderDamage: (UUID, Int32) -> Int32
    let playerHasPartner: (UUID) -> Bool
    
    @Environment(\.dismiss) private var dismiss
    
    private var playerColor: (gradient: [Color], accent: Color, border: Color) {
        ConclavePlayerColors.color(for: colorIndex)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ConclaveGradientBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Commander Damage Section (First)
                        commanderDamageSection
                        
                        // Poison Counter Section (Second)
                        poisonSection
                        
                        // Partner Commander Toggle (Last)
                        partnerToggleSection
                    }
                    .padding()
                }
            }
            .navigationTitle("\(player.displayName)'s Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.conclaveBackground.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.conclaveViolet)
                }
            }
        }
    }
    
    private var partnerToggleSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label("Partner Commander", systemImage: "shield.fill")
                    .font(.headline)
                    .foregroundColor(playerColor.accent)
                Text("Enable if this player has a partner commander")
                    .font(.caption)
                    .foregroundColor(.conclaveMuted)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { hasPartner },
                set: { _ in onTogglePartner() }
            ))
            .labelsHidden()
            .tint(.conclaveViolet)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: playerColor.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(playerColor.border, lineWidth: 1)
        )
    }
    
    private var poisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Poison Counters", systemImage: "drop.fill")
                .font(.headline)
                .foregroundColor(.purple)
            
            HStack(spacing: 20) {
                Button(action: { onPoisonChange(-1) }) {
                    Image(systemName: "minus")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(Color.purple.opacity(0.18))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                        )
                }
                .disabled(poisonCount <= 0)
                .opacity(poisonCount <= 0 ? 0.4 : 1)
                
                VStack(spacing: 4) {
                    Text("\(poisonCount)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(poisonColor)
                    Text("poison")
                        .font(.caption)
                        .foregroundColor(.conclaveMuted)
                }
                .frame(minWidth: 80)
                
                Button(action: { onPoisonChange(1) }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(Color.purple.opacity(0.18))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            
            if poisonCount >= 10 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Lethal poison!")
                }
                .font(.caption)
                .foregroundColor(.conclaveDanger)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.25), lineWidth: 1)
        )
    }
    
    private var poisonColor: Color {
        if poisonCount >= 10 {
            return .conclaveDanger
        } else if poisonCount >= 7 {
            return .orange
        } else if poisonCount > 0 {
            return .purple
        }
        return .white
    }
    
    private var commanderDamageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Commander Damage (Incoming)", systemImage: "burst.fill")
                .font(.headline)
                .foregroundColor(.orange)
            
            if otherPlayers.isEmpty {
                Text("No other players in the game")
                    .font(.subheadline)
                    .foregroundColor(.conclaveMuted)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(otherPlayers, id: \.id) { fromPlayer in
                        CommanderDamageCard(
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
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Commander Damage Card

struct CommanderDamageCard: View {
    let fromPlayer: Player
    let hasPartner: Bool
    let getCommanderDamage: (Int32) -> Int32
    let onDamageChange: (Int32, Int32) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Player header
            HStack(spacing: 10) {
                if let imageUrl = fromPlayer.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(fromPlayer.displayName.prefix(1)))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                
                Text(fromPlayer.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Total damage from this player
                let totalDamage = (1...(hasPartner ? 2 : 1)).reduce(0) { sum, cmdNum in
                    sum + getCommanderDamage(Int32(cmdNum))
                }
                if totalDamage > 0 {
                    Text("Total: \(totalDamage)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(totalDamage >= 21 ? .conclaveDanger : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill((totalDamage >= 21 ? Color.conclaveDanger : Color.orange).opacity(0.15))
                        )
                }
            }
            
            // Commander damage controls
            ForEach(1...(hasPartner ? 2 : 1), id: \.self) { cmdNum in
                commanderDamageControl(commanderNumber: Int32(cmdNum))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func commanderDamageControl(commanderNumber: Int32) -> some View {
        let damage = getCommanderDamage(commanderNumber)
        
        return HStack {
            Text(hasPartner ? "Commander \(commanderNumber)" : "Commander")
                .font(.subheadline)
                .foregroundColor(.conclaveMuted)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {
                    onDamageChange(commanderNumber, -1)
                }) {
                    Image(systemName: "minus")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .disabled(damage <= 0)
                .opacity(damage <= 0 ? 0.3 : 1)
                
                Text("\(damage)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(damageColor(damage))
                    .frame(minWidth: 32)
                
                Button(action: {
                    onDamageChange(commanderNumber, 1)
                }) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.08))
                        )
                }
            }
        }
    }
    
    private func damageColor(_ damage: Int32) -> Color {
        if damage >= 21 {
            return .conclaveDanger
        } else if damage >= 15 {
            return .orange
        }
        return .white
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
        }
    }
}

// MARK: - UUID Extension for Identifiable in sheet

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
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
