import Clerk
import SwiftUI

struct HomeScreenView: View {
    @Environment(\.clerk) private var clerk
    @Binding var screenPath: NavigationPath
    @State private var authIsPresented = false
    @State private var isAnimated = false

    var body: some View {
        ZStack {
            // Gradient background
            ConclaveGradientBackground()
            
            VStack(spacing: 0) {
                // Top bar with user button
                HStack {
                    Spacer()
                    if clerk.user != nil {
                        UserButton()
                            .frame(width: 40, height: 40)
                    } else {
                        Button(action: {
                            authIsPresented = true
                        }) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(ConclaveIconButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()
                
                // Main content
                VStack(spacing: 32) {
                    // Logo and title
                    VStack(spacing: 16) {
                        // Sparkle icon
                        Image(systemName: "sparkles")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.conclaveViolet, .conclavePink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .opacity(isAnimated ? 1 : 0)
                            .offset(y: isAnimated ? 0 : 10)
                            .animation(.easeOut(duration: 0.6).delay(0.1), value: isAnimated)
                        
                        // Title
                        Text("Conclave")
                            .font(.system(size: 56, weight: .black))
                            .gradientText()
                            .opacity(isAnimated ? 1 : 0)
                            .offset(y: isAnimated ? 0 : 20)
                            .animation(.easeOut(duration: 0.6).delay(0.2), value: isAnimated)
                        
                        // Subtitle
                        Text("MTG Life Tracker")
                            .font(.title3)
                            .foregroundColor(.conclaveMuted)
                            .opacity(isAnimated ? 1 : 0)
                            .offset(y: isAnimated ? 0 : 15)
                            .animation(.easeOut(duration: 0.6).delay(0.3), value: isAnimated)
                    }
                    
                    // Feature badges
                    HStack(spacing: 16) {
                        FeatureBadge(icon: "person.3.fill", text: "Up to 8 Players")
                        FeatureBadge(icon: "bolt.fill", text: "Real-time Sync")
                    }
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : 15)
                    .animation(.easeOut(duration: 0.6).delay(0.4), value: isAnimated)
                    
                    // Preview cards
                    HStack(spacing: 12) {
                        PreviewLifeCard(life: 40, playerName: "P1", colorIndex: 0)
                        PreviewLifeCard(life: 38, playerName: "P2", colorIndex: 1)
                        PreviewLifeCard(life: 32, playerName: "P3", colorIndex: 2)
                        PreviewLifeCard(life: 25, playerName: "P4", colorIndex: 3)
                    }
                    .padding(.horizontal, 20)
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.5), value: isAnimated)
                }
                
                Spacer()
                
                // Bottom action buttons
                VStack(spacing: 16) {
                    // Online Game Button (Primary)
                    Button(action: {
                        if clerk.user != nil {
                            screenPath.append(Screen.gameList)
                        } else {
                            authIsPresented = true
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "wifi")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Online Game")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [.conclaveViolet, .conclavePink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: .conclaveViolet.opacity(0.4), radius: 16, x: 0, y: 8)
                    }
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.6), value: isAnimated)
                    
                    // Offline Game Button (Secondary)
                    Button(action: {
                        screenPath.append(Screen.offlineGame)
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "iphone")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Offline Game")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.7), value: isAnimated)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $authIsPresented) {
            AuthView()
        }
        .onAppear {
            isAnimated = true
        }
    }
}

// MARK: - Feature Badge
struct FeatureBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.conclaveViolet)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.conclaveMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Preview Life Card
struct PreviewLifeCard: View {
    let life: Int
    let playerName: String
    let colorIndex: Int
    
    var body: some View {
        let playerColor = ConclavePlayerColors.color(for: colorIndex)
        
        VStack(spacing: 6) {
            Text(playerName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.conclaveMuted)
            Text("\(life)")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text("Life")
                .font(.system(size: 9))
                .foregroundColor(.conclaveMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: playerColor.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(playerColor.border, lineWidth: 1)
        )
    }
}

#Preview {
    HomeScreenView(screenPath: .constant(NavigationPath()))
}
