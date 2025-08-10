import SwiftUI
import SwiftData

struct SpellbookView: View {
    @Bindable var user: User

    // Live clock for buff durations
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Filtering within the grimoire
    private enum School: String, CaseIterable, Identifiable {
        case all = "All"
        case power = "Power"
        case economy = "Economy"
        case nature = "Nature"
        case guild = "Guild"
        case echoes = "Echoes"
        var id: String { rawValue }
    }
    @State private var selectedSchool: School = .all

    // Data
    private var allSpells: [Spell] {
        ItemDatabase.shared.masterSpellList.sorted { $0.requiredLevel < $1.requiredLevel }
    }
    private var unlockedSpells: [Spell] {
        allSpells.filter { user.unlockedSpellIDs.contains($0.id) }
    }
    private var lockedSpells: [Spell] {
        allSpells.filter { !user.unlockedSpellIDs.contains($0.id) }
    }

    var body: some View {
        ZStack {
            backgroundLeather()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerBar
                    openBook
                }
                .padding(.vertical, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { date in
            now = date
            SpellbookManager.shared.cleanupExpiredBuffs(for: user)
        }
    }

    // MARK: - Header & Background

    private var headerBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "book.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(.brown)
            Text("Grimoire")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "circle.hexagonpath")
                Text("\(user.runes)")
            }
            .font(.headline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal)
    }

    private func backgroundLeather() -> some View {
        LinearGradient(colors: [Color(red: 53/255, green: 33/255, blue: 21/255), Color(red: 26/255, green: 16/255, blue: 10/255)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .strokeBorder(.brown.opacity(0.4), lineWidth: 6)
                        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                        .padding(10)
                }
            )
    }

    // MARK: - Book Layout
    
    private var openBook: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let isWide = width >= 700
            let pageWidth = min(isWide ? 1000.0 : width - 32, width - 32)
            
            VStack(spacing: 16) {
                // Book spine tabs / filters
                filterTabs
                
                if isWide {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(.thinMaterial)
                            .overlay(bookTextureInset)
                            .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 10)
                        
                        // Two-page layout
                        HStack(spacing: 0) {
                            bookPageLeft
                                .frame(width: pageWidth/2)
                                .padding(.leading, 18)
                                .padding(.vertical, 18)
                            Divider().blendMode(.overlay)
                            bookPageRight
                                .frame(width: pageWidth/2)
                                .padding(.trailing, 18)
                                .padding(.vertical, 18)
                        }
                    }
                    .frame(width: pageWidth, alignment: .center)
                } else {
                    // Compact: stack pages vertically within the same styled container
                    ZStack {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(.thinMaterial)
                            .overlay(bookTextureInset)
                            .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 10)
                        
                        VStack(alignment: .leading, spacing: 18) {
                            bookPageLeft
                            Divider().blendMode(.overlay)
                            bookPageRight
                        }
                        .padding(18)
                    }
                    .frame(width: pageWidth, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .frame(height: max(520, proxy.size.height * 0.75))
        }
        .frame(minHeight: 520)
    }

    private var bookTextureInset: some View {
        RoundedRectangle(cornerRadius: 22)
            .stroke(.brown.opacity(0.25), lineWidth: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
                    .blendMode(.overlay)
            )
            .padding(2)
    }

    private var filterTabs: some View {
        HStack(spacing: 8) {
            ForEach(School.allCases) { school in
                let isSel = selectedSchool == school
                Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { selectedSchool = school } }) {
                    HStack(spacing: 6) {
                        Image(systemName: icon(for: school))
                        Text(school.rawValue)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(isSel ? Color.brown.opacity(0.25) : Color.brown.opacity(0.12))
                    .overlay(
                        Capsule().stroke(isSel ? Color.brown.opacity(0.6) : Color.brown.opacity(0.25), lineWidth: isSel ? 2 : 1)
                    )
                    .foregroundStyle(isSel ? .primary : .secondary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal)
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

    // Left page: Active effects, runes ledger
    private var bookPageLeft: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Effects")
                .font(.title3.weight(.heavy))
                .foregroundStyle(.primary)
            if user.isDoubleXpNextTask || !user.activeBuffs.isEmpty {
                VStack(spacing: 10) {
                    if user.isDoubleXpNextTask {
                        activeBuffRow(systemName: "sparkles", title: "Double XP (next task)")
                    }
                    ForEach(Array(user.activeBuffs.keys), id: \.self) { effect in
                        if let expiryDate = user.activeBuffs[effect] {
                            activeBuffRow(systemName: effect.systemImage, title: effect.displayName, expiry: expiryDate)
                        }
                    }
                }
                .padding(12)
                .background(parchmentBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                Text("No active effects. Cast a spell to begin.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(parchmentBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Text("Runes Ledger")
                .font(.title3.weight(.heavy))
            HStack {
                Image(systemName: "circle.hexagonpath.fill").foregroundStyle(.purple)
                Text("\(user.runes) Runes available")
                    .font(.headline)
                Spacer()
            }
            .padding(12)
            .background(parchmentBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Spacer(minLength: 0)
        }
    }

    private var parchmentBackground: some ShapeStyle {
        .linearGradient(colors: [Color(white: 0.98), Color(white: 0.94)], startPoint: .top, endPoint: .bottom)
    }

    private func activeBuffRow(systemName: String, title: String, expiry: Date? = nil) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemName)
                .foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                if let expiry {
                    let rem = max(0, Int(expiry.timeIntervalSince(now)))
                    ProgressView(value: progress(until: expiry)) {
                        Text(timeString(seconds: rem)).font(.caption).foregroundStyle(.secondary)
                    }
                    .progressViewStyle(.linear)
                }
            }
            Spacer()
        }
    }

    private func progress(until date: Date) -> Double {
        let total: Double = 600 // default 10m baseline; visual only
        let remaining = max(0, date.timeIntervalSince(now))
        return min(1.0, max(0.0, 1.0 - remaining / total))
    }

    private func timeString(seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    // Right page: Spell entries with locks
    private var bookPageRight: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spells")
                .font(.title3.weight(.heavy))

            let filteredUnlocked = unlockedSpells.filter { selectedSchool == .all || school(for: $0) == selectedSchool }
            let filteredLocked = lockedSpells.filter { selectedSchool == .all || school(for: $0) == selectedSchool }

            if filteredUnlocked.isEmpty && filteredLocked.isEmpty {
                Text("No spells in this school yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(parchmentBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredUnlocked) { spell in
                        spellEntry(spell: spell, isLocked: false)
                    }
                    if !filteredLocked.isEmpty {
                        Divider().padding(.vertical, 6)
                        ForEach(filteredLocked) { spell in
                            spellEntry(spell: spell, isLocked: true)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func spellEntry(spell: Spell, isLocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: spell.effect.systemImage)
                    .font(.title3)
                    .foregroundStyle(isLocked ? .gray : .purple)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(spell.name)
                        .font(.headline)
                        .foregroundStyle(isLocked ? .secondary : .primary)
                    Text(spell.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isLocked {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                        Text("Lv \(spell.requiredLevel)")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.gray.opacity(0.15), in: Capsule())
                }
            }

            HStack(alignment: .center) {
                Label("Cost: \(spell.runeCost)", systemImage: "circle.hexagonpath")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                castButton(spell: spell)
                    .disabled(isLocked || user.runes < spell.runeCost)
                    .opacity(isLocked ? 0.5 : 1)
            }
        }
        .padding(12)
        .background(parchmentBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.brown.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private func castButton(spell: Spell) -> some View {
        Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                SpellbookManager.shared.castSpell(spell, for: user)
            }
            // Reuse page turn as a magical rustle
            SensoryFeedbackManager.shared.trigger(for: .journalSaved)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                Text("Cast")
            }
            .font(.subheadline.bold())
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(LinearGradient(colors: [.purple.opacity(0.85), .indigo.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(color: .purple.opacity(0.3), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}
