import SwiftUI

// MARK: - Conclave Theme Colors
// Matching the web version's stunning purple/blue gradient aesthetic

extension Color {
    // Primary brand colors
    static let conclaveBackground = Color(red: 0.08, green: 0.06, blue: 0.14)
    static let conclaveCard = Color(red: 0.10, green: 0.08, blue: 0.18)
    static let conclavePrimary = Color(red: 0.55, green: 0.35, blue: 0.85)
    static let conclaveSecondary = Color(red: 0.15, green: 0.12, blue: 0.25)
    static let conclaveBorder = Color(red: 0.25, green: 0.20, blue: 0.40)
    
    // Accent colors for gradients
    static let conclaveViolet = Color(red: 0.55, green: 0.35, blue: 0.85)
    static let conclavePink = Color(red: 0.75, green: 0.35, blue: 0.65)
    static let conclaveBlue = Color(red: 0.35, green: 0.55, blue: 0.85)
    
    // Muted text
    static let conclaveMuted = Color(red: 0.55, green: 0.50, blue: 0.65)
    
    // Success/Danger
    static let conclaveSuccess = Color(red: 0.30, green: 0.75, blue: 0.55)
    static let conclaveDanger = Color(red: 0.85, green: 0.35, blue: 0.40)
}

// MARK: - Player Colors
struct ConclavePlayerColors {
    static let colors: [(gradient: [Color], accent: Color, border: Color)] = [
        // Violet/Purple
        (
            [Color(red: 0.55, green: 0.35, blue: 0.85).opacity(0.3), Color(red: 0.45, green: 0.25, blue: 0.65).opacity(0.1)],
            Color(red: 0.65, green: 0.45, blue: 0.95),
            Color(red: 0.55, green: 0.35, blue: 0.85).opacity(0.4)
        ),
        // Blue/Cyan
        (
            [Color(red: 0.30, green: 0.55, blue: 0.85).opacity(0.3), Color(red: 0.25, green: 0.65, blue: 0.75).opacity(0.1)],
            Color(red: 0.40, green: 0.65, blue: 0.95),
            Color(red: 0.30, green: 0.55, blue: 0.85).opacity(0.4)
        ),
        // Emerald/Green
        (
            [Color(red: 0.25, green: 0.75, blue: 0.55).opacity(0.3), Color(red: 0.20, green: 0.65, blue: 0.45).opacity(0.1)],
            Color(red: 0.35, green: 0.85, blue: 0.65),
            Color(red: 0.25, green: 0.75, blue: 0.55).opacity(0.4)
        ),
        // Amber/Orange
        (
            [Color(red: 0.85, green: 0.65, blue: 0.25).opacity(0.3), Color(red: 0.75, green: 0.55, blue: 0.20).opacity(0.1)],
            Color(red: 0.95, green: 0.75, blue: 0.35),
            Color(red: 0.85, green: 0.65, blue: 0.25).opacity(0.4)
        ),
        // Rose/Red
        (
            [Color(red: 0.85, green: 0.35, blue: 0.45).opacity(0.3), Color(red: 0.75, green: 0.25, blue: 0.35).opacity(0.1)],
            Color(red: 0.95, green: 0.45, blue: 0.55),
            Color(red: 0.85, green: 0.35, blue: 0.45).opacity(0.4)
        ),
        // Pink/Fuchsia
        (
            [Color(red: 0.85, green: 0.35, blue: 0.75).opacity(0.3), Color(red: 0.75, green: 0.25, blue: 0.65).opacity(0.1)],
            Color(red: 0.95, green: 0.45, blue: 0.85),
            Color(red: 0.85, green: 0.35, blue: 0.75).opacity(0.4)
        ),
        // Teal
        (
            [Color(red: 0.25, green: 0.70, blue: 0.70).opacity(0.3), Color(red: 0.20, green: 0.60, blue: 0.65).opacity(0.1)],
            Color(red: 0.35, green: 0.80, blue: 0.80),
            Color(red: 0.25, green: 0.70, blue: 0.70).opacity(0.4)
        ),
        // Indigo
        (
            [Color(red: 0.40, green: 0.35, blue: 0.85).opacity(0.3), Color(red: 0.35, green: 0.30, blue: 0.75).opacity(0.1)],
            Color(red: 0.50, green: 0.45, blue: 0.95),
            Color(red: 0.40, green: 0.35, blue: 0.85).opacity(0.4)
        ),
    ]
    
    static func color(for index: Int) -> (gradient: [Color], accent: Color, border: Color) {
        colors[index % colors.count]
    }
}

// MARK: - Gradient Background View
struct ConclaveGradientBackground: View {
    var body: some View {
        ZStack {
            // Base color
            Color.conclaveBackground
                .ignoresSafeArea()
            
            // Animated gradient orbs
            GeometryReader { geometry in
                ZStack {
                    // Top-left violet orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.conclaveViolet.opacity(0.25), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.5
                            )
                        )
                        .frame(width: geometry.size.width * 0.8, height: geometry.size.width * 0.8)
                        .position(x: geometry.size.width * 0.15, y: geometry.size.height * 0.15)
                        .blur(radius: 60)
                    
                    // Top-right blue orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.conclaveBlue.opacity(0.20), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.6
                            )
                        )
                        .frame(width: geometry.size.width * 0.9, height: geometry.size.width * 0.9)
                        .position(x: geometry.size.width * 0.85, y: geometry.size.height * 0.25)
                        .blur(radius: 70)
                    
                    // Bottom-center pink orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.conclavePink.opacity(0.15), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.5
                            )
                        )
                        .frame(width: geometry.size.width * 0.7, height: geometry.size.width * 0.7)
                        .position(x: geometry.size.width * 0.4, y: geometry.size.height * 0.85)
                        .blur(radius: 50)
                }
            }
        }
    }
}

// MARK: - Glass Card Modifier
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 20
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.conclaveCard.opacity(0.6))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Gradient Text Modifier
struct GradientText: ViewModifier {
    var colors: [Color] = [.conclaveViolet, .conclavePink]
    
    func body(content: Content) -> some View {
        content
            .foregroundStyle(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

extension View {
    func gradientText(colors: [Color] = [.conclaveViolet, .conclavePink]) -> some View {
        modifier(GradientText(colors: colors))
    }
}

// MARK: - Primary Button Style
struct ConclavePrimaryButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: isDestructive 
                        ? [Color.conclaveDanger, Color.conclaveDanger.opacity(0.8)]
                        : [Color.conclaveViolet, Color.conclavePink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: (isDestructive ? Color.conclaveDanger : Color.conclaveViolet).opacity(0.4), radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style
struct ConclaveSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Icon Button Style
struct ConclaveIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(12)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        ConclaveGradientBackground()
        
        VStack(spacing: 20) {
            Text("Conclave")
                .font(.system(size: 48, weight: .black))
                .gradientText()
            
            Text("The ultimate life tracker")
                .foregroundColor(.conclaveMuted)
            
            VStack(spacing: 12) {
                Text("40")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Life")
                    .foregroundColor(.conclaveMuted)
            }
            .glassCard()
            
            Button("Get Started") {}
                .buttonStyle(ConclavePrimaryButtonStyle())
            
            Button("Sign In") {}
                .buttonStyle(ConclaveSecondaryButtonStyle())
        }
        .padding()
    }
}
