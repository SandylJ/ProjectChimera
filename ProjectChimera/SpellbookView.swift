import SwiftUI
import SwiftData

struct SpellbookView: View {
    @Bindable var user: User
    
    // Timer to update the UI for buff durations
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var unlockedSpells: [Spell] {
        ItemDatabase.shared.masterSpellList.filter { user.unlockedSpellIDs.contains($0.id) }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Header
                HStack {
                    Text("Runes: \(user.runes)")
                        .font(.title2.bold())
                    Text("🌀")
                        .font(.title)
                }
                .padding([.horizontal, .top])
                
                // Active Buffs Section
                activeBuffsView
                
                // Spells Section
                Section(header: Text("Spells").font(.title2).bold().padding(.horizontal)) {
                    if unlockedSpells.isEmpty {
                        Text("Level up your character to learn new spells.")
                            .padding().frame(maxWidth: .infinity)
                            .background(Material.thin).cornerRadius(10)
                            .padding(.horizontal)
                    } else {
                        ForEach(unlockedSpells) { spell in
                            spellCardView(spell: spell)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Spellbook")
        .onReceive(timer) { newDate in
            self.now = newDate
            SpellbookManager.shared.cleanupExpiredBuffs(for: user)
        }
    }
    
    @ViewBuilder
    private var activeBuffsView: some View {
        if user.isDoubleXpNextTask || !user.activeBuffs.isEmpty {
            Section(header: Text("Active Effects").font(.title2).bold().padding(.horizontal)) {
                VStack(alignment: .leading) {
                    if user.isDoubleXpNextTask {
                        buffRowView(systemName: "sparkles", color: .purple, text: "Double XP on next task")
                    }
                    ForEach(Array(user.activeBuffs.keys), id: \.self) { effect in
                        if let expiryDate = user.activeBuffs[effect] {
                            buffRowView(systemName: "dollarsign.circle.fill", color: .yellow, text: "Double Gold (\(timeRemaining(until: expiryDate)))")
                        }
                    }
                }
                .padding().background(Material.regular).cornerRadius(15).padding(.horizontal)
            }
        }
    }
    
    private func buffRowView(systemName: String, color: Color, text: String) -> some View {
        HStack {
            Image(systemName: systemName)
                .foregroundColor(color)
                .font(.headline)
            Text(text)
                .font(.callout)
        }
    }
    
    private func spellCardView(spell: Spell) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(spell.name).font(.headline)
            Text(spell.description).font(.caption).foregroundColor(.secondary)
            Divider()
            HStack {
                Text("Cost: \(spell.runeCost) 🌀")
                Spacer()
                Button("Cast") {
                    SpellbookManager.shared.castSpell(spell, for: user)
                }
                .buttonStyle(.bordered).tint(.purple)
                .disabled(user.runes < spell.runeCost)
            }
        }
        .padding()
        .background(Material.regular)
        .cornerRadius(15)
        .padding(.horizontal)
    }
    
    private func timeRemaining(until date: Date) -> String {
        let remaining = date.timeIntervalSince(now)
        if remaining <= 0 { return "Expired" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        return formatter.string(from: remaining) ?? "..."
    }
}
