import Clerk
import ConclaveKit
import SwiftUI

struct GameListView: View {
    @Binding var screenPath: NavigationPath
    @Environment(ConclaveClientManager.self) private var conclave
    @Environment(\.clerk) private var clerk
    @State private var showCreateSheet = false
    @State private var selectedStartingLife: Int32 = 40
    
    // Check if user is in an active game
    private var hasActiveGame: Bool {
        guard let game = conclave.currentGame else { return false }
        return game.status == .active
    }
    
    // Find the user's active game from the list (if they have one)
    private var activeGameFromList: GameWithUsers? {
        guard let currentGame = conclave.currentGame, currentGame.status == .active else { return nil }
        return conclave.allGames.first { $0.game.id == currentGame.id }
    }
    
    // Available games excluding the user's active game
    private var availableGames: [GameWithUsers] {
        guard let currentGame = conclave.currentGame else { return conclave.allGames }
        return conclave.allGames.filter { $0.game.id != currentGame.id }
    }

    var body: some View {
        ZStack {
            // Background
            ConclaveGradientBackground()
            
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Button(action: {
                        showCreateSheet = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("New Game")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(hasActiveGame ? .conclaveMuted : .white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Group {
                                if hasActiveGame {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.08))
                                } else {
                                    LinearGradient(
                                        colors: [.conclaveViolet, .conclavePink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                }
                            }
                        )
                        .cornerRadius(12)
                        .shadow(color: hasActiveGame ? .clear : .conclaveViolet.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .disabled(hasActiveGame)
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
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(ConclaveIconButtonStyle())
                }
                .task {
                    await setupAuthAndFetchGames()
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Active Game Section
                        if hasActiveGame {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.conclaveSuccess)
                                    Text("Your Active Game")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                
                                if let activeGame = activeGameFromList {
                                    Button(action: {
                                        Task {
                                            await resumeGame(gameId: activeGame.game.id)
                                        }
                                    }) {
                                        ActiveGameCard(gameWithUsers: activeGame)
                                    }
                                    .buttonStyle(.plain)
                                } else if let currentGame = conclave.currentGame {
                                    // If we have a current game but it's not in the list yet
                                    Button(action: {
                                        Task {
                                            await resumeGame(gameId: currentGame.id)
                                        }
                                    }) {
                                        ActiveGameCardSimple(game: currentGame, playerCount: conclave.allPlayers.count)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                // Info message
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 12))
                                    Text("Leave or finish your current game to join another")
                                        .font(.caption)
                                }
                                .foregroundColor(.conclaveMuted)
                                .padding(.top, 4)
                            }
                        }
                        
                        // Available Games Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Available Games")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            if availableGames.isEmpty && !hasActiveGame && conclave.allGames.isEmpty {
                                // No games at all
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
                                    
                                    Text("No games available")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text("Create a new game to get started")
                                        .font(.subheadline)
                                        .foregroundColor(.conclaveMuted)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else if availableGames.isEmpty && hasActiveGame {
                                // Only user's game exists
                                VStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.conclaveSuccess.opacity(0.5))
                                    
                                    Text("No other games available")
                                        .font(.subheadline)
                                        .foregroundColor(.conclaveMuted)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(availableGames) { item in
                                        Button(action: {
                                            Task {
                                                await joinGame(gameId: item.game.id)
                                            }
                                        }) {
                                            GameCard(gameWithUsers: item, isDisabled: hasActiveGame)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(hasActiveGame)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
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
        
        // Fetch user's active game from backend (source of truth for one-game enforcement)
        do {
            try await conclave.fetchUserActiveGame()
        } catch {
            print("Failed to fetch user's active game: \(error)")
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
        // Don't allow joining if already in an active game
        guard !hasActiveGame else {
            print("Cannot join game - already in an active game")
            return
        }
        
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
    
    private func resumeGame(gameId: UUID) async {
        do {
            // Reconnect to WebSocket if needed
            if !conclave.isConnectedToWebSocket {
                try await conclave.connectToWebSocket(gameId: gameId)
            }
            screenPath.append(Screen.onlineGame)
        } catch {
            print("Failed to resume game: \(error)")
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

// MARK: - Active Game Card
struct ActiveGameCard: View {
    let gameWithUsers: GameWithUsers
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Game #\(gameWithUsers.game.id.uuidString.prefix(8))")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    // Live indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.conclaveSuccess)
                            .frame(width: 6, height: 6)
                        Text("Live")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.conclaveSuccess)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.conclaveSuccess.opacity(0.15))
                    )
                }
                
                HStack(spacing: 16) {
                    // Starting life
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.conclaveDanger)
                        Text("\(gameWithUsers.game.startingLife)")
                            .font(.caption)
                            .foregroundColor(.conclaveDanger)
                    }
                    
                    // Player count
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text("\(gameWithUsers.users.count) players")
                            .font(.caption)
                    }
                    .foregroundColor(.conclaveMuted)
                }
            }
            
            Spacer()
            
            // Resume button
            HStack(spacing: 4) {
                Text("Resume")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.conclaveSuccess)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.conclaveSuccess.opacity(0.15), Color.conclaveSuccess.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.conclaveSuccess.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Active Game Card Simple (when game not in list)
struct ActiveGameCardSimple: View {
    let game: Game
    let playerCount: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Game #\(game.id.uuidString.prefix(8))")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    // Live indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.conclaveSuccess)
                            .frame(width: 6, height: 6)
                        Text("Live")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.conclaveSuccess)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.conclaveSuccess.opacity(0.15))
                    )
                }
                
                HStack(spacing: 16) {
                    // Starting life
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.conclaveDanger)
                        Text("\(game.startingLife)")
                            .font(.caption)
                            .foregroundColor(.conclaveDanger)
                    }
                    
                    // Player count
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text("\(playerCount) players")
                            .font(.caption)
                    }
                    .foregroundColor(.conclaveMuted)
                }
            }
            
            Spacer()
            
            // Resume button
            HStack(spacing: 4) {
                Text("Resume")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.conclaveSuccess)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.conclaveSuccess.opacity(0.15), Color.conclaveSuccess.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.conclaveSuccess.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Game Card
struct GameCard: View {
    let gameWithUsers: GameWithUsers
    var isDisabled: Bool = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Game #\(gameWithUsers.game.id.uuidString.prefix(8))")
                    .font(.headline)
                    .foregroundColor(isDisabled ? .conclaveMuted : .white)
                
                HStack(spacing: 16) {
                    // Starting life
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(isDisabled ? .conclaveMuted : .conclaveDanger)
                        Text("\(gameWithUsers.game.startingLife)")
                            .font(.caption)
                            .foregroundColor(isDisabled ? .conclaveMuted : .conclaveDanger)
                    }
                    
                    // Player count
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text("\(gameWithUsers.users.count) players")
                            .font(.caption)
                    }
                    .foregroundColor(.conclaveMuted)
                    
                    // Status badge
                    Text(gameWithUsers.game.status.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(gameWithUsers.game.status == .active 
                                      ? Color.conclaveSuccess.opacity(isDisabled ? 0.1 : 0.2) 
                                      : Color.white.opacity(0.1))
                        )
                        .foregroundColor(gameWithUsers.game.status == .active 
                                         ? (isDisabled ? .conclaveMuted : .conclaveSuccess)
                                         : .conclaveMuted)
                }
            }
            
            Spacer()
            
            if isDisabled {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.conclaveMuted)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.conclaveMuted)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(isDisabled ? 0.04 : 0.08), Color.white.opacity(isDisabled ? 0.01 : 0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(isDisabled ? 0.06 : 0.12), lineWidth: 1)
        )
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
            ZStack {
                ConclaveGradientBackground()
                
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Starting Life")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Choose the starting life total for all players")
                            .font(.subheadline)
                            .foregroundColor(.conclaveMuted)
                    }
                    .padding(.top)
                    
                    HStack(spacing: 12) {
                        ForEach(lifeOptions, id: \.self) { life in
                            Button(action: {
                                startingLife = life
                            }) {
                                VStack(spacing: 6) {
                                    Text("\(life)")
                                        .font(.title)
                                        .fontWeight(.bold)
                                    Text("Life")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(startingLife == life 
                                              ? LinearGradient(colors: [.conclaveViolet, .conclavePink], startPoint: .topLeading, endPoint: .bottomTrailing) 
                                              : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(startingLife == life ? Color.clear : Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        Text("Format Suggestions")
                            .font(.caption)
                            .foregroundColor(.conclaveMuted)
                        HStack(spacing: 20) {
                            HStack(spacing: 4) {
                                Image(systemName: "rectangle.stack")
                                    .font(.caption2)
                                Text("Standard: 20")
                                    .font(.caption2)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "crown")
                                    .font(.caption2)
                                Text("Commander: 40")
                                    .font(.caption2)
                            }
                        }
                        .foregroundColor(.conclaveMuted)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        onCreate(startingLife)
                        dismiss()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Create Game")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.conclaveViolet, .conclavePink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                        .shadow(color: .conclaveViolet.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.conclaveBackground.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.conclaveViolet)
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
