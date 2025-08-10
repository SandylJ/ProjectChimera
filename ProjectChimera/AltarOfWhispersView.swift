

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
                        courtesiesView(altar: altar)
                        ritualsView(altar: altar)
                    } else {
                        Text("The Altar is dormant. Return later.")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
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
                 if user.activeBuffs.keys.contains(where: { if case .echoBoost = $0 { return true } else { return false } }) {
                     Label("Echo Surge", systemImage: "bolt.fill")
                 }
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

    // MARK: - Courtesies
    private func courtesiesView(altar: AltarOfWhispers) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Whisper Courtesies")
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.horizontal)

            VStack(spacing: 12) {
                courtesyRow(
                    key: "echo_flow",
                    title: "Echo Flow",
                    description: "+5% global Echoes per level.",
                    baseCost: 150
                )
                courtesyRow(
                    key: "garden_whispers",
                    title: "Garden Whispers",
                    description: "Plants grow 10% faster per level.",
                    baseCost: 200
                )
                courtesyRow(
                    key: "expedition_echo_kickback",
                    title: "Echo Kickback",
                    description: "+2 Echoes per party member on expedition completion per level.",
                    baseCost: 180
                )
                courtesyRow(
                    key: "shop_patron",
                    title: "Patron of the Bazaar",
                    description: "Shop chest costs reduced by 5% per level (max 50%).",
                    baseCost: 250
                )
            }
            .padding(.horizontal)
        }
    }

    private func courtesyRow(key: String, title: String, description: String, baseCost: Double) -> some View {
        let level = user.altarCourtesies[key] ?? 0
        let cost = baseCost * pow(2.0, Double(level))
        let canAfford = (altar?.echoes ?? 0.0) >= cost
        return VStack(alignment: .leading, spacing: 8) {
            HStack { Text(title).font(.headline); Spacer(); Text("Lvl. \(level)").font(.headline).foregroundColor(.secondary) }
            Text(description).font(.caption).foregroundColor(.secondary)
            Button(action: {
                guard let altar = altar, altar.echoes >= cost else { return }
                altar.echoes -= cost
                var map = user.altarCourtesies
                map[key] = level + 1
                user.altarCourtesies = map
            }) {
                HStack { Image(systemName: "hands.sparkles"); Text(String(format: "Bestow (%.0f Echoes)", cost)) }.frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(canAfford ? .cyan : .gray)
            .disabled(!canAfford)
        }
        .padding()
        .background(Material.regular)
        .cornerRadius(15)
    }

    // MARK: - Rituals
    private func ritualsView(altar: AltarOfWhispers) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Rituals")
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.horizontal)

            VStack(spacing: 12) {
                // Echo Surge Buff
                ritualRow(
                    title: "Echo Surge",
                    description: "Boost Echoes by +50% for 10 minutes.",
                    costText: "Cost: 100 Echoes",
                    canAfford: altar.echoes >= 100
                ) {
                    if altar.echoes >= 100 { altar.echoes -= 100 }
                    // 10 minute surge with +50%
                    let surge = SpellEffect.echoBoost(0.5)
                    let duration: TimeInterval = 600
                    let expiry = Date().addingTimeInterval(duration)
                    user.activeBuffs[surge] = expiry
                }

                // Whisper Cache: random courtesy materials from garden/inventory for echoes
                ritualRow(
                    title: "Whisper Cache",
                    description: "Offer 3 random materials to gain 60 Echoes.",
                    costText: "Cost: 3 materials",
                    canAfford: hasAtLeastNMaterials(3)
                ) {
                    if consumeMaterials(3) {
                        altar.echoes += 60
                    }
                }

                // Transmute Echoes -> Gold
                ritualRow(
                    title: "Transmute: Gold",
                    description: "Convert 50 Echoes into 500 Gold.",
                    costText: "Cost: 50 Echoes",
                    canAfford: altar.echoes >= 50
                ) {
                    if altar.echoes >= 50 {
                        altar.echoes -= 50
                        user.gold += 500
                    }
                }

                // Transmute Echoes -> Runes
                ritualRow(
                    title: "Transmute: Runes",
                    description: "Convert 100 Echoes into 5 Runes.",
                    costText: "Cost: 100 Echoes",
                    canAfford: altar.echoes >= 100
                ) {
                    if altar.echoes >= 100 {
                        altar.echoes -= 100
                        user.runes += 5
                    }
                }

                // Transmute Echoes -> Willpower
                ritualRow(
                    title: "Transmute: Willpower",
                    description: "Convert 25 Echoes into 50 Willpower.",
                    costText: "Cost: 25 Echoes",
                    canAfford: altar.echoes >= 25
                ) {
                    if altar.echoes >= 25 {
                        altar.echoes -= 25
                        user.willpower += 50
                    }
                }

                // Offer Gold for Echoes
                ritualRow(
                    title: "Golden Offering",
                    description: "Tithe 1,000 Gold to gain 80 Echoes.",
                    costText: "Cost: 1000 Gold",
                    canAfford: user.gold >= 1000
                ) {
                    if user.gold >= 1000 {
                        user.gold -= 1000
                        altar.echoes += 80
                    }
                }

                // Offer Runes for Echoes
                ritualRow(
                    title: "Runic Offering",
                    description: "Offer 3 Runes to gain 120 Echoes.",
                    costText: "Cost: 3 Runes",
                    canAfford: user.runes >= 3
                ) {
                    if user.runes >= 3 {
                        user.runes -= 3
                        altar.echoes += 120
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func ritualRow(title: String, description: String, costText: String, canAfford: Bool, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text(costText).font(.caption).foregroundColor(.secondary)
            }
            Text(description).font(.caption).foregroundColor(.secondary)
            Button(action: action) {
                HStack { Image(systemName: "wand.and.stars"); Text("Perform Ritual") }.frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(canAfford ? .purple : .gray)
            .disabled(!canAfford)
        }
        .padding()
        .background(Material.regular)
        .cornerRadius(15)
    }

    // MARK: - Inventory helpers
    private func hasAtLeastNMaterials(_ n: Int) -> Bool {
        let mats = (user.inventory ?? []).filter { ItemDatabase.shared.getItem(id: $0.itemID)?.itemType == .material && $0.quantity > 0 }
        return mats.reduce(0) { $0 + $1.quantity } >= n
    }
    private func consumeMaterials(_ n: Int) -> Bool {
        var remaining = n
        guard var inventory = user.inventory else { return false }
        for inv in inventory where remaining > 0 {
            guard ItemDatabase.shared.getItem(id: inv.itemID)?.itemType == .material else { continue }
            let take = min(inv.quantity, remaining)
            inv.quantity -= take
            remaining -= take
        }
        // Cleanup zero-quantity items
        user.inventory = inventory.filter { $0.quantity > 0 }
        return remaining == 0
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
