

import SwiftUI
import SwiftData

struct AltarOfWhispersView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var user: User

    @State private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @State private var particles: [Particle] = []

    private var altar: AltarOfWhispers? {
        user.altarOfWhispers
    }

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Particle Effects
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
                    .animation(.easeInOut(duration: 1.0), value: particle.opacity)
            }

            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    
                    if let altar = altar {
                        statsView(altar: altar)
                        upgradesView(altar: altar)
                    } else {
                        Text("The Altar is dormant. Return later.")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Altar of Whispers")
        .onAppear(perform: setup)
        .onReceive(timer) { _ in
            updateParticles()
            if let altar = altar {
                altar.echoes += altar.echoesPerSecond * 0.1
            }
        }
    }

    private func setup() {
        if user.altarOfWhispers == nil {
            IdleGameManager.shared.initializeAltar(for: user, context: modelContext)
        }
        IdleGameManager.shared.processOfflineProgress(for: user)
    }

    private var headerView: some View {
        VStack {
            Image(systemName: "flame.fill")
                .font(.system(size: 60))
                .foregroundColor(.cyan)
                .shadow(color: .white, radius: 10)

            Text("Altar of Whispers")
                .font(.largeTitle).bold()
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("The whispers of forgotten tasks empower the altar, generating echoes of reality.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private func statsView(altar: AltarOfWhispers) -> some View {
        VStack(spacing: 10) {
            Text(String(format: "%.2f Echoes", altar.echoes))
                .font(.system(.title, design: .monospaced).bold())
                .foregroundColor(.white)
            
            HStack {
                Label(String(format: "%.2f/sec", IdleGameManager.shared.totalEchoesPerSecond(for: user)), systemImage: "arrow.up.right.circle.fill")
                Label(String(format: "%.2f Gold/sec", altar.goldPerSecond), systemImage: "dollarsign.circle.fill")
                Label(String(format: "%.4f Runes/sec", altar.runesPerSecond), systemImage: "sparkles")
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(15)
    }

    private func upgradesView(altar: AltarOfWhispers) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Upgrades")
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.horizontal)

            UpgradeRowView(
                title: "Altar Attunement",
                level: altar.level,
                description: String(format: "Increases base Echo generation to %.2f/sec.", (Double(altar.level + 1) * 0.1)),
                cost: altar.upgradeCost,
                canAfford: altar.echoes >= altar.upgradeCost,
                action: { 
                    IdleGameManager.shared.upgradeAltar(for: user)
                    triggerHapticFeedback()
                }
            )

            UpgradeRowView(
                title: "Echo Amplifier",
                level: altar.echoMultiplierLevel,
                description: String(format: "Multiplies Echo generation by x%.2f.", (1.0 + (Double(altar.echoMultiplierLevel) * 0.25))),
                cost: altar.echoMultiplierUpgradeCost,
                canAfford: altar.echoes >= altar.echoMultiplierUpgradeCost,
                action: { 
                    IdleGameManager.shared.upgradeEchoMultiplier(for: user)
                    triggerHapticFeedback()
                }
            )
            
            UpgradeRowView(
                title: "Golden Whispers",
                level: altar.goldGenerationLevel,
                description: String(format: "Generates %.2f Gold per second.", (Double(altar.goldGenerationLevel + 1) * 0.5)),
                cost: altar.goldGenerationUpgradeCost,
                canAfford: altar.echoes >= altar.goldGenerationUpgradeCost,
                action: { 
                    IdleGameManager.shared.upgradeGoldGeneration(for: user)
                    triggerHapticFeedback()
                }
            )
            
            UpgradeRowView(
                title: "Runic Resonance",
                level: altar.runeGenerationLevel,
                description: String(format: "Generates %.4f Runes per second.", (Double(altar.runeGenerationLevel + 1) * 0.001)),
                cost: altar.runeGenerationUpgradeCost,
                canAfford: altar.echoes >= altar.runeGenerationUpgradeCost,
                action: { 
                    IdleGameManager.shared.upgradeRuneGeneration(for: user)
                    triggerHapticFeedback()
                }
            )
        }
    }

    private func triggerHapticFeedback() {
        // Haptic feedback removed for macOS compatibility
    }

    private func updateParticles() {
        particles = particles.filter { $0.opacity > 0 }
        let newParticle = Particle(
            position: CGPoint(x: 200, y: 100), // Fixed position instead of UIScreen
            color: [.cyan, .purple, .blue].randomElement()!,
            size: CGFloat.random(in: 5...15)
        )
        particles.append(newParticle)
        
        for i in 0..<particles.count {
            particles[i].opacity -= 0.01
            particles[i].position.y += CGFloat.random(in: -2...2)
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double = 1.0
}

// MARK: - Reusable Upgrade Row View
struct UpgradeRowView: View {
    let title: String
    let level: Int
    let description: String
    let cost: Double
    let canAfford: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("Lvl. \(level)")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: action) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                    Text(String(format: "Upgrade for %.1f Echoes", cost))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(canAfford ? .cyan : .gray)
            .disabled(!canAfford)
        }
        .padding()
        .background(Material.regular)
        .cornerRadius(15)
    }
}
