import ConclaveKit
import SwiftUI

enum LifeOrientation: Double {
    case Up = 0
    case Left = 90
    case Right = 270
    case Down = 180
}

struct UserHealthView: View {
    var healthColor: Color
    var lifeOrientation: LifeOrientation
    var player: Player
    @Environment(ConclaveClientManager.self) private var conclave

    init(
        _ player: Player,
        _ healthColor: SwiftUICore.Color,
        lifeOrientation: LifeOrientation = .Up,
    ) {
        self.player = player
        self.healthColor = healthColor
        self.lifeOrientation = lifeOrientation
    }

    struct HealthButtons: View {
        var player: Player
        var givenLifeOrientation: LifeOrientation
        @State private var leftHoldTimer: Timer?
        @State private var rightHoldTimer: Timer?
        @Environment(ConclaveClientManager.self) private var conclave

        private func changeHealth(_ healthChange: Int32) {
            Task {
                do {
                    try await conclave.sendLifeUpdate(
                        playerId: player.id,
                        changeAmount: healthChange
                    )
                } catch {
                    print("\(error)")
                }
            }
        }

        private func subAddStartTimer(isLeft: Bool) {
            if isLeft {
                changeHealth(-10)
                leftHoldTimer = Timer.scheduledTimer(
                    withTimeInterval: 0.5,
                    repeats: true
                ) { _ in
                    changeHealth(-10)
                }
            } else {
                changeHealth(10)
                rightHoldTimer = Timer.scheduledTimer(
                    withTimeInterval: 0.5,
                    repeats: true
                ) { _ in
                    changeHealth(10)
                }
            }
        }

        private func stopTimer(isLeft: Bool) {
            if isLeft {
                leftHoldTimer?.invalidate()
                leftHoldTimer = nil
            } else {
                rightHoldTimer?.invalidate()
                rightHoldTimer = nil
            }
        }

        var body: some View {
            let flipLeftRight =
                (givenLifeOrientation == .Right
                    || givenLifeOrientation == .Down)
            let flipAngle: Double =
                (givenLifeOrientation == .Right
                    || givenLifeOrientation == .Left) ? 90 : 0
            ZStack {
                Color
                    .clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if flipLeftRight {
                            changeHealth(1)
                        } else {
                            changeHealth(-1)
                        }
                    }
                    .gesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                subAddStartTimer(isLeft: !flipLeftRight)
                            }
                            .simultaneously(
                                with: DragGesture(minimumDistance: 0)
                            )
                            .onEnded { _ in
                                stopTimer(isLeft: !flipLeftRight)
                            }
                    )
                Image(systemName: flipLeftRight ? "plus" : "minus")
                    .rotationEffect(Angle(degrees: flipAngle))
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .padding(10)
            }
            ZStack {
                Color
                    .clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if flipLeftRight {
                            changeHealth(-1)
                        } else {
                            changeHealth(1)
                        }
                    }
                    .gesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                subAddStartTimer(isLeft: flipLeftRight)
                            }
                            .simultaneously(
                                with: DragGesture(minimumDistance: 0)
                            )
                            .onEnded { _ in
                                stopTimer(isLeft: flipLeftRight)
                            }
                    )
                Image(systemName: flipLeftRight ? "minus" : "plus")
                    .rotationEffect(Angle(degrees: flipAngle))
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .padding(10)
            }
        }

    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(healthColor)

                Text("\(player.currentLife)")
                    .foregroundStyle(.white)
                    .rotationEffect(Angle(degrees: lifeOrientation.rawValue))
                    .font(.system(size: geo.size.width * 0.3))
                    .minimumScaleFactor(0.1)

                if lifeOrientation == .Left || lifeOrientation == .Right {
                    VStack(spacing: 0) {
                        HealthButtons(
                            player: player,
                            givenLifeOrientation: lifeOrientation
                        )
                        .environment(conclave)
                    }
                } else {
                    HStack(spacing: 0) {
                        HealthButtons(
                            player: player,
                            givenLifeOrientation: lifeOrientation
                        )
                        .environment(conclave)
                    }
                }
                VStack {
                    Text("\(player.clerkUserId)")
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    @Previewable @State var mockManager: ConclaveClientManager =
        ConclaveClientManager(client: MockConclaveClient.testing)
    if mockManager.isConnectedToWebSocket {
        HStack {
            UserHealthView(
                mockManager.allPlayers[0],
                .red,
                lifeOrientation: .Up
            )
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
                } catch {
                    print("Failed to create game: \(error)")
                }
            }
    }
}
