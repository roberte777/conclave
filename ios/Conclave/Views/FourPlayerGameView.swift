import SwiftUI

struct FourPlayerGameView: View {
    @Binding var screenPath: NavigationPath
    @State private var players: [OfflinePlayer] = [
        OfflinePlayer(name: "Player 1", life: 40, colorIndex: 0),
        OfflinePlayer(name: "Player 2", life: 40, colorIndex: 1),
        OfflinePlayer(name: "Player 3", life: 40, colorIndex: 2),
        OfflinePlayer(name: "Player 4", life: 40, colorIndex: 3),
    ]
    @State private var animatingPlayers: Set<Int> = []

    var body: some View {
        ZStack {
            // Background
            ConclaveGradientBackground()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        screenPath = NavigationPath()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(ConclaveIconButtonStyle())
                    
                    Spacer()
                    
                    Text("Offline Game")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        // Reset all players
                        for i in players.indices {
                            players[i].life = 40
                        }
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(ConclaveIconButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Players grid
                GeometryReader { geometry in
                    let spacing: CGFloat = 12
                    let cardWidth = (geometry.size.width - spacing * 3) / 2
                    let cardHeight = (geometry.size.height - spacing * 3) / 2
                    
                    VStack(spacing: spacing) {
                        HStack(spacing: spacing) {
                            OfflinePlayerCard(
                                player: $players[0],
                                isAnimating: animatingPlayers.contains(0),
                                onLifeChange: { amount in
                                    changeLife(playerIndex: 0, amount: amount)
                                }
                            )
                            .frame(width: cardWidth, height: cardHeight)
                            
                            OfflinePlayerCard(
                                player: $players[1],
                                isAnimating: animatingPlayers.contains(1),
                                onLifeChange: { amount in
                                    changeLife(playerIndex: 1, amount: amount)
                                }
                            )
                            .frame(width: cardWidth, height: cardHeight)
                        }
                        
                        HStack(spacing: spacing) {
                            OfflinePlayerCard(
                                player: $players[2],
                                isAnimating: animatingPlayers.contains(2),
                                onLifeChange: { amount in
                                    changeLife(playerIndex: 2, amount: amount)
                                }
                            )
                            .frame(width: cardWidth, height: cardHeight)
                            
                            OfflinePlayerCard(
                                player: $players[3],
                                isAnimating: animatingPlayers.contains(3),
                                onLifeChange: { amount in
                                    changeLife(playerIndex: 3, amount: amount)
                                }
                            )
                            .frame(width: cardWidth, height: cardHeight)
                        }
                    }
                    .padding(spacing)
                }
            }
        }
    }
    
    private func changeLife(playerIndex: Int, amount: Int) {
        players[playerIndex].life += amount
        animatingPlayers.insert(playerIndex)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            animatingPlayers.remove(playerIndex)
        }
    }
}

// MARK: - Offline Player Model
struct OfflinePlayer: Identifiable {
    let id = UUID()
    var name: String
    var life: Int
    var colorIndex: Int
}

// MARK: - Offline Player Card
struct OfflinePlayerCard: View {
    @Binding var player: OfflinePlayer
    let isAnimating: Bool
    let onLifeChange: (Int) -> Void
    
    private var playerColor: (gradient: [Color], accent: Color, border: Color) {
        ConclavePlayerColors.color(for: player.colorIndex)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Player name
            Text(player.name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.conclaveMuted)
                .padding(.top, 12)
            
            Spacer()
            
            // Life total
            VStack(spacing: 4) {
                Text("\(player.life)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundColor(lifeColor)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeOut(duration: 0.1), value: isAnimating)
                
                Text("Life")
                    .font(.caption)
                    .foregroundColor(.conclaveMuted)
            }
            
            Spacer()
            
            // Life controls
            HStack(spacing: 0) {
                // Decrease side
                Button(action: { onLifeChange(-1) }) {
                    HStack {
                        Image(systemName: "minus")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.conclaveDanger)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.conclaveDanger.opacity(0.15))
                }
                
                // Increase side
                Button(action: { onLifeChange(1) }) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.conclaveSuccess)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.conclaveSuccess.opacity(0.15))
                }
            }
            .frame(height: 56)
        }
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
                .stroke(playerColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var lifeColor: Color {
        if player.life <= 5 {
            return .conclaveDanger
        } else if player.life <= 10 {
            return .orange
        }
        return .white
    }
}

#Preview {
    FourPlayerGameView(screenPath: .constant(NavigationPath()))
}
