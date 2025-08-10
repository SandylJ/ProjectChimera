import SwiftUI
import SwiftData

struct SpellbookDashboardView: View {
    @Bindable var user: User

    // Live clock for timers/progress
    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Filters and UI state
    private enum School: String, CaseIterable, Identifiable { case all = "All", power = "Power", economy = "Economy", nature = "Nature", guild = "Guild", echoes = "Echoes"; var id: String { rawValue } }
    @State private var selectedSchool: School = .all

    // Cached particle state for ambience
    @State private var particles: [ArcaneParticle] = []

    // MARK: - Data
    private var allSpells: [Spell] {
        ItemDatabase.shared.masterSpellList.sorted { $0.requiredLevel < $1.requiredLevel }
    }
    private var unlockedSpells: [Spell] {
        allSpells.filter { user.unlockedSpellIDs.contains($0.id) }
    }
    private var lockedSpells: [Spell] {
        allSpells.filter { !user.unlockedSpellIDs.contains($0.id) }
    }

    private var altar: AltarOfWhispers? { user.altarOfWhispers }

    var body: some View {
        ZStack {
            animatedArcaneBackground
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerBar
                    metricsDeck
                    activeBuffsPanel
                    spellsCarousel
                }
                .padding(.vertical, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { date in
            now = date
            SpellbookManager.shared.cleanupExpiredBuffs(for: user)
            updateParticles()
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(LinearGradient(colors: [.purple.opacity(0.35), .indigo.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                    .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 6)
                Image(systemName: "wand.and.stars")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Arcane Nexus").font(.title.bold()).foregroundStyle(.white)
                Text("Harness spells, manage buffs, and track your magical economy").font(.footnote).foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "circle.hexagonpath")
                Text("\(user.runes)")
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .font(.headline)
            .foregroundStyle(.white)
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    // MARK: - Metrics Deck
    private var metricsDeck: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                metricCard(title: "Active Buffs", value: "\(user.activeBuffs.count)", icon: "sparkles", tint: .purple)
                metricCard(title: "Runes", value: "\(user.runes)", icon: "circle.hexagonpath.fill", tint: .indigo)
            }
            HStack(spacing: 12) {
                metricCard(title: "Echoes/sec", value: String(format: "%.2f", IdleGameManager.shared.totalEchoesPerSecond(for: user)), icon: "waveform.path.ecg", tint: .cyan)
                metricCard(title: "Gold/sec", value: String(format: "%.2f", altar?.goldPerSecond ?? 0.0), icon: "dollarsign.circle.fill", tint: .yellow)
                metricCard(title: "Runes/sec", value: String(format: "%.4f", altar?.runesPerSecond ?? 0.0), icon: "sparkles", tint: .mint)
            }
        }
        .padding(.horizontal)
    }

    private func metricCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: icon).foregroundStyle(tint); Spacer() }
            Text(value).font(.system(.title2, design: .rounded).bold()).foregroundStyle(.white)
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.8))
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.35), lineWidth: 1.25)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: tint.opacity(0.25), radius: 10, x: 0, y: 6)
    }

    // MARK: - Active Buffs Panel
    private var activeBuffsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Effects").font(.title3.weight(.heavy)).foregroundStyle(.white)
                Spacer()
                if user.isDoubleXpNextTask { labelChip(text: "Next Task: 2x XP", icon: "sparkles", tint: .purple) }
            }

            if user.isDoubleXpNextTask || !user.activeBuffs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(user.activeBuffs.keys), id: \.self) { effect in
                            if let expiryDate = user.activeBuffs[effect] {
                                BuffRing(effect: effect, now: now, expiry: expiryDate)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Text("No active effects. Cast a spell to begin.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(.horizontal)
    }

    private func labelChip(text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) { Image(systemName: icon); Text(text) }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(tint.opacity(0.15), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.4), lineWidth: 1))
            .foregroundStyle(.white)
    }

    // MARK: - Spells Carousel/Grid
    private var spellsCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Grimoire")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
                Spacer()
                NavigationLink(destination: LegacySpellbookWrapper(user: user)) {
                    HStack(spacing: 6) { Image(systemName: "book.fill"); Text("Classic") }
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(.white)
                }
            }

            filterTabs

            let filteredUnlocked = unlockedSpells.filter { selectedSchool == .all || school(for: $0) == selectedSchool }
            let filteredLocked = lockedSpells.filter { selectedSchool == .all || school(for: $0) == selectedSchool }

            if filteredUnlocked.isEmpty && filteredLocked.isEmpty {
                Text("No spells in this school yet.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
            } else {
                // Horizontal carousel for unlocked, then a faint row for locked
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(filteredUnlocked) { spell in
                            spellCard(spell: spell, isLocked: false)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 2)
                }
                if !filteredLocked.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(filteredLocked) { spell in
                                spellCard(spell: spell, isLocked: true)
                            }
                        }
                        .opacity(0.6)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(School.allCases) { school in
                    let isSelected = selectedSchool == school
                    Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { selectedSchool = school } }) {
                        HStack(spacing: 6) {
                            Image(systemName: icon(for: school))
                            Text(school.rawValue)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
                        .overlay(Capsule().stroke(Color.white.opacity(isSelected ? 0.6 : 0.25), lineWidth: isSelected ? 2 : 1))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private func icon(for school: School) -> String {
        switch school {
        case .all: return "sparkles"
        case .power: return "bolt.fill"
        case .economy: return "dollarsign.circle.fill"
        case .nature: return "leaf.fill"
        case .guild: return "person.3.fill"
        case .echoes: return "waveform.path.ecg"
        }
    }

    private func school(for spell: Spell) -> School {
        switch spell.effect {
        case .doubleXP, .xpBoost, .willpowerGeneration: return .power
        case .doubleGold, .goldBoost, .runeBoost, .reducedUpgradeCost: return .economy
        case .plantGrowthSpeed: return .nature
        case .guildXpBoost: return .guild
        case .echoBoost: return .echoes
        }
    }

    // MARK: - Spell Card
    @ViewBuilder
    private func spellCard(spell: Spell, isLocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: spell.effect.systemImage)
                    .font(.title3)
                    .foregroundStyle(isLocked ? .gray : .white)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(spell.name)
                        .font(.headline)
                        .foregroundStyle(isLocked ? .white.opacity(0.8) : .white)
                    Text(spell.description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                }
                Spacer()
            }

            HStack(alignment: .center) {
                Label("Cost: \(spell.runeCost)", systemImage: "circle.hexagonpath")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                castButton(spell: spell)
                    .disabled(isLocked || user.runes < spell.runeCost)
                    .opacity(isLocked ? 0.5 : 1)
            }
        }
        .padding(14)
        .background(
            LinearGradient(colors: [.white.opacity(0.10), .white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                .blendMode(.overlay)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
        .frame(width: 300)
    }

    private func castButton(spell: Spell) -> some View {
        Button {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                SpellbookManager.shared.castSpell(spell, for: user)
            }
        } label: {
            HStack(spacing: 6) { Image(systemName: "wand.and.stars"); Text("Cast") }
                .font(.subheadline.bold())
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(LinearGradient(colors: [.purple.opacity(0.9), .indigo.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: .purple.opacity(0.35), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Animated Background
    private var animatedArcaneBackground: some View {
        LinearGradient(colors: [Color(red: 25/255, green: 16/255, blue: 52/255), Color(red: 10/255, green: 8/255, blue: 28/255)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            .overlay(
                ZStack {
                    // Floating particles
                    ForEach(particles) { particle in
                        Circle()
                            .fill(particle.color)
                            .frame(width: particle.size, height: particle.size)
                            .position(particle.position)
                            .opacity(particle.opacity)
                    }

                    // Subtle vignette frame
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 20)
                        .padding(10)
                        .blendMode(.overlay)
                }
            )
    }

    private func updateParticles() {
        particles = particles.filter { $0.opacity > 0.02 }
        if particles.count < 60 {
            let new = ArcaneParticle.random(in: spawnRect())
            particles.append(new)
        }
        for index in particles.indices {
            particles[index].opacity -= 0.02
            particles[index].position.x += CGFloat.random(in: -0.6...0.6)
            particles[index].position.y += CGFloat.random(in: -0.6...0.6)
        }
    }
    
    private func spawnRect() -> CGRect {
        // Fallback safe rect for platforms without UIScreen
        return CGRect(x: 0, y: 0, width: 800, height: 1200)
    }
}

// MARK: - Ring View for Buffs
private struct BuffRing: View {
    let effect: SpellEffect
    let now: Date
    let expiry: Date

    private var remainingSeconds: Double { max(0, expiry.timeIntervalSince(now)) }
    private var totalVisual: Double { 600 } // purely visual baseline
    private var progress: Double { min(1.0, max(0.0, 1.0 - remainingSeconds / totalVisual)) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(AngularGradient(gradient: Gradient(colors: [.purple, .indigo, .cyan, .purple]), center: .center), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: effect.systemImage)
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)

            Text(effect.displayName)
                .font(.caption2)
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(timeString(seconds: Int(remainingSeconds)))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func timeString(seconds: Int) -> String {
        guard seconds > 0 else { return "Expired" }
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Particle Model
private struct ArcaneParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double

    static func random(in rect: CGRect) -> ArcaneParticle {
        ArcaneParticle(
            position: CGPoint(x: CGFloat.random(in: rect.minX...rect.maxX), y: CGFloat.random(in: rect.minY...rect.maxY)),
            color: [Color.purple.opacity(0.25), Color.indigo.opacity(0.25), Color.cyan.opacity(0.25)].randomElement() ?? Color.purple.opacity(0.25),
            size: CGFloat.random(in: 6...14),
            opacity: Double.random(in: 0.35...0.8)
        )
    }
}

// MARK: - Legacy Wrapper Navigation
private struct LegacySpellbookWrapper: View {
    @Bindable var user: User
    var body: some View {
        SpellbookView(user: user)
            .navigationTitle("Classic Grimoire")
    }
}