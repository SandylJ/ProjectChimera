import SwiftUI
import SwiftData

struct QuestsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var user: User
    
    @State private var showRewardPopup = false
    @State private var lastQuestRewards: [LootReward] = []
    
    private var activeQuests: [Quest] {
        user.quests?.filter { $0.status == .active } ?? []
    }
    
    private var availableQuests: [Quest] {
        user.quests?.filter { $0.status == .available } ?? []
    }
    
    private var completedQuests: [Quest] {
        user.quests?.filter { $0.status == .completed } ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Completed Quests Section
                if !completedQuests.isEmpty {
                    Section(header: Text("Completed").font(.title2).bold().padding(.horizontal)) {
                        ForEach(completedQuests) { quest in
                            QuestCardView(quest: quest, user: user, onClaim: {
                                lastQuestRewards = quest.rewards
                                QuestManager.shared.claimQuestReward(for: quest, on: user, context: modelContext)
                                showRewardPopup = true
                            })
                        }
                    }
                }
                
                // Active Quests Section
                Section(header: Text("Active").font(.title2).bold().padding(.horizontal)) {
                    if activeQuests.isEmpty {
                        Text("Accept a quest from the board below.").padding().frame(maxWidth: .infinity).background(Material.thin).cornerRadius(10).padding(.horizontal)
                    } else {
                        ForEach(activeQuests) { quest in
                            QuestCardView(quest: quest, user: user, onClaim: {})
                        }
                    }
                }
                
                // Available Quests Section
                Section(header: Text("Available").font(.title2).bold().padding(.horizontal)) {
                    ForEach(availableQuests) { quest in
                        QuestCardView(quest: quest, user: user, onClaim: {})
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Quest Board")
        .sheet(isPresented: $showRewardPopup) {
            QuestRewardPopup(rewards: $lastQuestRewards, isPresented: $showRewardPopup)
        }
    }
}

// MARK: - Quest Card View
struct QuestCardView: View {
    @Bindable var quest: Quest
    @Bindable var user: User
    var onClaim: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(quest.title).font(.headline).bold()
            Text(quest.questDescription).font(.caption).italic().foregroundColor(.secondary)
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Objective:").font(.caption).bold()
                Text(quest.objectiveDescription).font(.caption)
            }
            
            if quest.status == .active {
                // Simplified progress display
                Text("Progress: \(quest.progress)").font(.caption)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Rewards:").font(.caption).bold()
                ForEach(quest.rewards) { reward in
                    RewardRowView(reward: reward)
                }
            }
            
            actionButton
        }
        .padding().background(Material.regular).cornerRadius(15).padding(.horizontal)
    }
    
    @ViewBuilder
    private var actionButton: some View {
        switch quest.status {
        case .available:
            Button("Accept Quest") {
                quest.status = .active
            }
            .buttonStyle(JuicyButtonStyle()).tint(.blue)
        case .active:
            EmptyView() // No button for active quests
        case .completed:
            Button("Claim Reward") {
                onClaim()
            }
            .buttonStyle(JuicyButtonStyle()).tint(.green)
        }
    }
}

// MARK: - Reward Views
struct RewardRowView: View {
    let reward: LootReward
    
    // --- FIX: Added @ViewBuilder to resolve the compiler error ---
    @ViewBuilder
    var body: some View {
        HStack {
            switch reward {
            case .currency(let amount):
                Image(systemName: "dollarsign.circle.fill").foregroundColor(.yellow)
                Text("\(amount) Gold")
            case .item(let id, let quantity):
                if let item = ItemDatabase.shared.getItem(id: id) {
                    Image(systemName: item.icon).foregroundColor(.blue)
                    Text("\(item.name) (x\(quantity))")
                }
            case .experienceBurst(let skill, let amount):
                Image(systemName: "sparkles").foregroundColor(.purple)
                Text("+\(amount) \(skill.rawValue.capitalized) XP")
            case .runes(let amount):
                Image(systemName: "circle.hexagonpath.fill").foregroundColor(.cyan)
                Text("\(amount) Runes")
            case .echoes(let amount):
                Image(systemName: "speaker.wave.2.circle.fill").foregroundColor(.gray)
                Text(String(format: "%.2f Echoes", amount))
            }
        }
        .font(.caption)
    }
}

struct QuestRewardPopup: View {
    @Binding var rewards: [LootReward]
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Quest Complete!")
                .font(.largeTitle).bold()
            
            Text("You earned:")
                .font(.headline)
            
            ForEach(rewards) { reward in
                RewardRowView(reward: reward)
                    .font(.title3)
            }
            
            Button("Awesome!") {
                isPresented = false
            }
            .buttonStyle(JuicyButtonStyle())
        }
        .padding()
    }
}
