import ConclaveKit
import SwiftUI

struct ContentView: View {
    @Environment(ConclaveClientManager.self) private var conclave

    // Test user info
    @State private var startingLife: Int32 = 40

    // Life change controls
    @State private var lifeChangeAmount: Int32 = -1
    @State private var selectedPlayerId: UUID?

    // UI State
    @State private var showingCreateGame = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // Header
                    headerSection

                    // Current Game Status
                    gameStatusSection

                    // Game Actions
                    gameActionsSection

                    // Players Section
                    if !conclave.allPlayers.isEmpty {
                        playersSection
                    }

                    // Life Changes History
                    if !conclave.recentLifeChanges.isEmpty {
                        recentChangesSection
                    }

                    // Error Display
                    if let error = conclave.lastError {
                        errorSection(error)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Conclave Test")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingCreateGame) {
            createGameSheet
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("🧙‍♂️ Magic Life Tracker")
                .font(.title2)
                .fontWeight(.bold)

            Text("Test the full game flow with WebSocket updates")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Game Status Section

    private var gameStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Game Status")
                .font(.headline)

            HStack(spacing: 16) {
                // Connection Status
                HStack {
                    Circle()
                        .fill(conclave.isConnectedToWebSocket ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(
                        conclave.isConnectedToWebSocket
                            ? "Connected" : "Disconnected"
                    )
                    .font(.caption)
                }

                // Loading Status
                if conclave.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                            .font(.caption)
                    }
                }

                Spacer()
            }

            // Current Game Info
            if let game = conclave.currentGame {
                VStack(alignment: .leading, spacing: 4) {
                    Text("📋 Game #\(game.id.uuidString.prefix(8))")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Status: \(game.status.rawValue.capitalized)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Starting Life: \(game.startingLife)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No active game")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Game Actions Section

    private var gameActionsSection: some View {
        VStack(spacing: 12) {
            Text("Game Actions")
                .font(.headline)

            if conclave.currentGame == nil {
                // No game - show create option
                VStack(spacing: 8) {
                    Button("🎮 Create New Game") {
                        showingCreateGame = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(conclave.isLoading)
                }
            } else {
                // Has game - show game management options
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Button("🔄 Refresh Game State") {
                            refreshGameState()
                        }
                        .buttonStyle(.bordered)
                        .disabled(
                            conclave.isLoading
                                || !conclave.isConnectedToWebSocket
                        )

                        Button("🚪 Leave Game") {
                            leaveGame()
                        }
                        .buttonStyle(.bordered)
                        .disabled(conclave.isLoading)
                    }

                    Button("🏁 End Game") {
                        endGame()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(conclave.isLoading)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Players Section

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Players (\(conclave.allPlayers.count))")
                .font(.headline)

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ],
                spacing: 12
            ) {
                ForEach(conclave.allPlayers) { player in
                    playerCard(player)
                }
            }

            // Life Change Controls
            if conclave.isConnectedToWebSocket && !conclave.allPlayers.isEmpty {
                lifeChangeControls
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func playerCard(_ player: Player) -> some View {
        VStack(spacing: 8) {
            // Player indicator
            HStack {
                Text("Player \(player.position)")
                    .font(.caption)
                    .fontWeight(.medium)

                if player.id == conclave.currentPlayer?.id {
                    Text("(You)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }

                Spacer()
            }

            // Life total
            Text("\(player.currentLife)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(player.currentLife <= 0 ? .red : .primary)

            Text("Life")
                .font(.caption2)
                .foregroundColor(.secondary)

            // Life change buttons
            if conclave.isConnectedToWebSocket {
                HStack(spacing: 4) {
                    Button("-5") { changeLife(player.id, -5) }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)

                    Button("-1") { changeLife(player.id, -1) }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)

                    Button("+1") { changeLife(player.id, 1) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)

                    Button("+5") { changeLife(player.id, 5) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    player.id == selectedPlayerId
                        ? Color.blue.opacity(0.1) : Color(.systemBackground)
                )
                .stroke(
                    player.id == selectedPlayerId ? Color.blue : Color.clear
                )
        )
        .onTapGesture {
            selectedPlayerId = player.id
        }
    }

    private var lifeChangeControls: some View {
        VStack(spacing: 8) {
            Text("Custom Life Change")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                TextField("Amount", value: $lifeChangeAmount, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)

                Button("Apply to Selected") {
                    if let playerId = selectedPlayerId {
                        changeLife(playerId, lifeChangeAmount)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedPlayerId == nil)
            }

            if selectedPlayerId == nil {
                Text("Tap a player card to select them")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }

    // MARK: - Recent Changes Section

    private var recentChangesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Changes")
                .font(.headline)

            ForEach(conclave.recentLifeChanges.prefix(5), id: \.id) { change in
                HStack {
                    Text("Player \(playerPosition(for: change.playerId))")
                        .font(.caption)
                        .fontWeight(.medium)

                    Spacer()

                    Text(
                        "\(change.changeAmount > 0 ? "+" : "")\(change.changeAmount)"
                    )
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(change.changeAmount > 0 ? .green : .red)

                    Text("→ \(change.newLifeTotal)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Error Section

    private func errorSection(_ error: ConclaveError) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("⚠️ Error")
                    .font(.headline)
                    .foregroundColor(.red)

                Spacer()

                Button("Dismiss") {
                    conclave.clearError()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text(error.errorDescription ?? "Unknown error")
                .font(.subheadline)
                .foregroundColor(.red)

            if error.isRecoverable, let retryDelay = error.retryDelay {
                Text(
                    "This error is recoverable. Try again in \(Int(retryDelay)) seconds."
                )
                .font(.caption)
                .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Sheets

    private var createGameSheet: some View {
        NavigationView {
            Form {
                Section("Game Details") {
                    Stepper(
                        "Starting Life: \(startingLife)",
                        value: $startingLife,
                        in: 1...100,
                        step: 1
                    )
                }
            }
            .navigationTitle("Create Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCreateGame = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createGame()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func createGame() {
        Task {
            do {
                let game = try await conclave.createGame(
                    startingLife: startingLife
                )

                showingCreateGame = false

                // Auto-connect to WebSocket
                try await conclave.connectToWebSocket(gameId: game.id)

            } catch {
                print("Failed to create game: \(error)")
            }
        }
    }

    private func refreshGameState() {
        Task {
            do {
                try await conclave.requestGameState()
            } catch {
                print("Failed to refresh game state: \(error)")
            }
        }
    }

    private func leaveGame() {
        guard let game = conclave.currentGame else { return }

        Task {
            do {
                try await conclave.leaveGame(gameId: game.id)
                conclave.clearCurrentGame()
            } catch {
                print("Failed to leave game: \(error)")
            }
        }
    }

    private func endGame() {
        Task {
            do {
                try await conclave.sendEndGame(winnerPlayerId: nil)
            } catch {
                print("Failed to end game: \(error)")
            }
        }
    }

    private func changeLife(_ playerId: UUID, _ amount: Int32) {
        Task {
            do {
                try await conclave.sendLifeUpdate(
                    playerId: playerId,
                    changeAmount: amount
                )
            } catch {
                print("Failed to update life: \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func playerPosition(for playerId: UUID) -> Int32 {
        conclave.allPlayers.first { $0.id == playerId }?.position ?? 0
    }
}
